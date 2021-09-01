#' @title Entrena el modelo de textos de AREA para Acuacar y genera el binario,
#' la ficha con las medidas de rendimiento del modelo y la matriz de confusión 
#' 
#' @description ESte modelo es el codificado como 1.2. Los datos necesarios para 
#' correr el modelo se encuentran aquí: 
#' metadatos: "datos/ACUACAR_Activo_2020_06_01_A_2021_02_10_V1.xlsx"
#' texto: "datos/acuacar.feather"
#' 

## ----setup, include=FALSE-----------------------------------------------------------------

library(digest)
library(dplyr)
library(janitor)
library(readxl)
library(readr)
library(stringr)
library(text2vec)
library(tidyr)
library(lubridate)
library(stringr)
library(tidymodels)
library(tidytext)
library(stopwords)
library(purrr)
library(textrecipes)
library(discrim)
library(themis)
library(jsonlite)
library(qdapRegex)
library(tictoc)
library(ranger)

library(doParallel)
all_cores <- parallel::detectCores(logical = FALSE)
registerDoParallel(cores = all_cores - 2)

vacias <- c(stopwords("es"))
n_tokens <- 500
n_trees <- 500
quiebre = 1

seed <- 4321
set.seed(seed)




## ----lee texto----------------------------------------------------------------------------
textos <- arrow::read_feather("datos/acuacar.feather") %>%
  mutate(path = str_remove(path,coll("/samba/acuafiles/ACTIVO/")),
         path = str_replace_all(path,coll("/"),"\\"))
#  mutate(pages = as.numeric(pages)) %>%
#  drop_na()



## ----lee metadados------------------------------------------------------------------------
crudos <- read_excel("datos/ACUACAR_Activo_2020_06_01_A_2021_02_10_V1.xlsx") %>%
  clean_names()

datos <- crudos %>%
  select(code,
         modo,
         name,
         date_created,
         date_modified,
         author,
         org_interesada_remitente,
         org_interesada_destinatario,
         nombre_fichero,
         mime_type,
         size,
         path,
         area,
         nombre_tipo_documental,
         codigo_tipo_documental,
         nombre_padre,
         codigo_padre,
         nombre_abuelo,
         codigo_abuelo,
         en_expte,
         nombre_serie_documental,
         codigo_serie_documental,
         dependencia_responsable) %>%
  unite(org_interesada,org_interesada_remitente:org_interesada_destinatario,
        remove = TRUE,
        na.rm = TRUE) %>%
  mutate(
    date_created = ymd_hms(date_created,tz = "UTC",locale = "es_CO.utf8")  - hours(5),
    date_modified = ymd_hms(date_modified,tz = "UTC", locale = "es_CO.utf8") - hours(5)
    ) %>%
  mutate(
    mes_creacion = month(date_created,label = FALSE,abbr = FALSE),
    dia_semana_creacion = wday(date_created,label = FALSE,
                               week_start = 1,abbr = FALSE),
    dia_creacion = day(date_created),
    hora_creacion = hour(date_created),
    mes_modificacion = month(date_modified,label = FALSE,abbr = FALSE),
    dia_semana_modificacion = wday(date_modified,label = FALSE,
                                   week_start = 1,abbr = FALSE),
    dia_modificacion = day(date_modified),
    hora_modificacion = hour(date_modified))




## ----filtro 1-----------------------------------------------------------------------------
autores_automaticos <- c("acuacarweb","pqrweb","admin", "partner")

datos <- datos %>%
  filter(modo != "S") %>%
  filter(!author %in% autores_automaticos)



## ----mostrar tipos de areas---------------------------------------------------------------
tabla <- datos %>%
  group_by(area) %>%
  summarize(frecuencia = n()) %>%
  arrange(desc(frecuencia)) %>%
  mutate(
    total = sum(frecuencia),
    porcentaje = (frecuencia/total)*100,
    acumulado = cumsum(porcentaje),
    posicion = 1:n()
    ) %>%
  select(-total) %>%
  ungroup()


# Sacamos los nombres de las categorías que tienen menos del `r
# quiebre`% de representación en los datos:
otros <- tabla %>%
  filter(porcentaje < quiebre) %>%
  pull(area)


# Reclasificamos bajo "otros" esas categorías
datos <- datos %>%
  mutate(
    tipo = factor(if_else(
      area %in% otros,"otros",area))
  )

# Guardamos el número de tipos diferentes considerados:
n_tipos <- datos %>%
  select(tipo) %>%
  distinct() %>%
  pull() %>%
  length()




## ----unir texto y metadatos---------------------------------------------------------------
todo <- left_join(datos,textos, by = "path",keep = TRUE) %>%
 drop_na(text) %>%
  select(-c(path.y,code.y)) %>%
  rename(path = path.x,
         code = code.x)

todo_textos <- todo %>%
  select(path,tipo,text) %>%
  mutate(
   text = str_replace_all(text, "[^[:alpha:]]", " "),
         # Quita espacios en blanco múltiples
   text = str_replace_all(text, "\\s+", " "),
         # Convierte palabras con acento a sin acento
   text = iconv(text,from = "UTF-8",to = "ASCII//TRANSLIT"),
   text = rm_nchar_words(text, "1"))



## ----division-----------------------------------------------------------------------------
division <- initial_split(todo_textos, strata = tipo)
entrenamiento <- training(division)
prueba <- testing(division)
pliegos <- vfold_cv(entrenamiento,strata = tipo)


## ----especificacion modelo----------------------------------------------------------------
rf_spec <- rand_forest() %>%
  set_args(trees = 500) %>%
  set_engine("ranger", importance = "impurity") %>%
  set_mode("classification")


## ----receta modelo------------------------------------------------------------------------
receta <- recipe(tipo ~ text,
                 data = entrenamiento) %>%
  step_upsample(tipo, over_ratio = 1) %>%
  step_tokenize(text) %>%
  step_stopwords(text,language = "es") %>%
  step_tokenfilter(text,max_tokens = n_tokens) %>%
  step_tfidf(text)



## ----flujo modelo-------------------------------------------------------------------------
flujo <- workflow() %>%
  add_model(rf_spec) %>%
  add_recipe(receta)


## ----ajustar modelo-----------------------------------------------------------------------
tic()
modelo_rs <- fit_resamples(
  flujo,
  pliegos,
  control = control_resamples(save_pred = TRUE)
  #metrics = metric_set(accuracy, sensitivity, specificity)
)
toc()


## ----evaluar modelo-----------------------------------------------------------------------
# metricas <- collect_metrics(modelo_rs)
# predicciones <- collect_predictions(modelo_rs)
#metricas

# precision <- metricas %>%
#   slice(1) %>%
#   select(mean) %>%
#   pull()
#log_metric("accuracy",precision)

# area_roc <- metricas %>%
#   slice(2) %>%
#   select(mean) %>%
#   pull()
#log_metric("roc_auc",area_roc)





## ----evaluacion prueba--------------------------------------------------------------------
final_rf <- flujo %>%
  last_fit(split = division)



## ----metricas prueba----------------------------------------------------------------------
final_res_metrics <- collect_metrics(final_rf)
final_res_predictions <- collect_predictions(final_rf)
correlacion_matthews <- mcc(final_res_predictions,truth = tipo, estimate = .pred_class)
final_res_metrics <- bind_rows(final_res_metrics, correlacion_matthews) %>%
  select(-.config)

write_csv(final_res_metrics,"ficha_mod_1_2.csv")

# precision <- final_res_metrics %>%
#   slice(1) %>%
#   select(.estimate) %>%
#   pull()
#log_metric("accuracy",precision)

# area_roc <- final_res_metrics %>%
#   slice(2) %>%
#   select(.estimate) %>%
#   pull()
#log_metric("roc_auc",area_roc)

# mat_cor <- final_res_metrics %>%
#   slice(3) %>%
#   select(.estimate) %>%
#   pull()
#log_metric("mcc",mat_cor)



## ----importancia de variables-------------------------------------------------------------
#jpeg('importance_plot.jpeg')
# final_rf %>%
#   pluck(".workflow", 1) %>%
#   pull_workflow_fit() %>%
#   vip(geom = "point", num_features = 15)
#dev.off()
#log_image('feature_importance', 'importance_plot.jpeg')


## ----confusion final----------------------------------------------------------------------
#jpeg('matriz_confusion.jpeg')

matriz_confusion <- final_res_predictions %>%
  conf_mat(truth = tipo, estimate = .pred_class)

write.table(matriz_confusion$table,"matriz_confusion_mod_1_2.csv", sep = ",")

# final_res_predictions %>%
#   conf_mat(truth = tipo, estimate = .pred_class) %>%
#   autoplot(type = "heatmap")
# dev.off()
# log_image('matriz_confusion', 'matriz_confusion.jpeg')



## ----curva ROC para conjunto de prueba----------------------------------------------------
#jpeg('curvas_roc.jpeg')
# final_res_predictions %>%
#   roc_curve(truth = tipo, .pred_1000:.pred_otros,na_rm = TRUE) %>%
#   autoplot()
#dev.off()
# log_image('curvas_roc', 'curvas_roc.jpeg')



## ---- eval = TRUE, guardar----------------------------------------------------------------
mejor <- flujo %>%
  fit(data = entrenamiento)

saveRDS(mejor, file = "modelo_1_2.rds")
#write_csv(final_res_metrics,"ficha_texto_filtro1.csv")
#log_artifact('modelo_texto_filtro1.rds')

#stop_experiment()


