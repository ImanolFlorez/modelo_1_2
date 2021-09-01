#' @title Genera datos de ejemplo de textos para ACUACAR
#' 
#' @description Utilizando como base los datos con los que se entreno el modelo,
#' toma una muestra de datos que sirven como ejemplo de un nuevo conjunto de 
#' datos con el cual se van a generar predicciones. Asume que los datos se
#' encuentran aquí: 
#' metadatos: "datos/ACUACAR_Activo_2020_06_01_A_2021_02_10_V1.xlsx"
#' texto: "datos/acuacar.feather"
#' 
#' @param numero es el número de muestras a generar
#'

args <- commandArgs(trailingOnly = TRUE)

numero <- as.numeric(args[1])

library(readxl)
library(readr)
library(dplyr)
library(stringr)
library(arrow)

# textos <- arrow::read_feather("datos/acuacar.feather") %>%
#   mutate(path = str_remove(path,coll("/samba/acuafiles/ACTIVO/")),
#          path = str_replace_all(path,coll("/"),"\\"))

autores_automaticos <- c("acuacarweb","pqrweb","admin", "partner")


datos <- read_excel("datos/ACUACAR_Activo_2020_06_01_A_2021_02_10_V1.xlsx") %>%
  # AREA es NA, pues no se tiene al inicio y es lo que se quiere predecir
  mutate(AREA = NA) %>%
  # Filtro 1, entrada y excluye autores automáticos
  filter(Modo != "S") %>%
  filter(!author %in% autores_automaticos) %>%
  slice_sample(n = numero) 

# caminos <- datos %>% 
#   select(path) %>% 
#   pull()
# 
# textos_datos <- textos %>% 
#   filter(path %in% caminos)

datos %>%
  write_csv("muestra_1_2.csv")


