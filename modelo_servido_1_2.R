args <- commandArgs(trailingOnly = TRUE)

#' Predice con el modelo de area para textos de acuacar (modelo 1.2)
#'
#' Asume que el modelo fue creado previamente y esta almacenado en un archivo
#' "modelo_1_2.rds"
#'
#' @param datos_file nombre del archivo .csv con los datos a predecir (metadatos)
#' @param text_file nombre del archivo .feather donde se encuentran los textos
#' @param resultados nombre del archivo .csv con los resultados de las predicciones
#'
#' @return Escribe archivo con los resultados de las predicciones
#' 
#' @description En los parametros de entrada, nombre puede indicar también el 
#' directorio a la carpeta en cuestión.
#' `text_file` es donde se encuentran todos los textos.
#'  
predecir_textos <- function(datos_file,text_file,resultados_file) {
  library(readr)
  library(janitor)
  library(tidymodels)
  library(textrecipes)
  library(readxl)
  library(dplyr)
  library(lubridate)
  library(stringr)
  library(qdapRegex)


  # Se excluyen los autores automáticos
  #autores_automaticos <- c("acuacarweb","pqrweb","admin", "partner")

  # se excluyen las areas con representación menor al 1%
  # otros <- c("1803", "1721", "1304", "1800", "1502", "1602", "1820",
  #                  "1505", "1600", "1200", "1202", "1501", "1210","1701",
  #                  "1702", "1401", "1402", "1711", "1801", "1900")

  muestra_metadatos <- read_csv(datos_file) %>%
    clean_names() %>%
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
      hora_modificacion = hour(date_modified)) %>%

    # Crea tipo como area y una categoria para otros
    mutate(
      tipo = factor(area))


  
  ## ----lee texto--------------------------------------------------------------
  textos <- arrow::read_feather(text_file) %>%
    mutate(path = str_remove(path,coll("/samba/acuafiles/ACTIVO/")),
           path = str_replace_all(path,coll("/"),"\\"))

  ## ----une texto + metadatos -------------------------------------------------  
  
  todo <- left_join(muestra_metadatos,textos, by = "path",keep = TRUE) %>%
    drop_na(text) %>%
    select(-c(path.y,code.y)) %>%
    rename(path = path.x,
           code = code.x)
  
  muestra_textos <- todo %>%
    select(path,tipo,text) %>%
    mutate(
      text = str_replace_all(text, "[^[:alpha:]]", " "),
      # Quita espacios en blanco múltiples
      text = str_replace_all(text, "\\s+", " "),
      # Convierte palabras con acento a sin acento
      text = iconv(text,from = "UTF-8",to = "ASCII//TRANSLIT"),
      text = rm_nchar_words(text, "1"))
  
  
  ### Obtener modelo -------------------------------------------------------------
  modelo <- readRDS("modelo_1_2.rds")

  ### Obtener predicciones -------------------------------------------------------
  clase <- predict(modelo,new_data = muestra_textos, type = "class")
  probabilidad <- predict(modelo,new_data = muestra_textos, type = "prob")

  ### Calcular y escribir resultados ---------------------------------------------
  resultados <- cbind.data.frame(clase,probabilidad)
  write_csv(resultados,file = resultados_file)

  }

### LLamar a la funcion con el nombre de los parametros dados ------------------
entrada_meta <- args[1]
entrada_text <- args[2]
salida <- args[3]

predecir_textos(entrada_meta,entrada_text,salida)
