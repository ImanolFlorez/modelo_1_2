
# Modelo 1.1: Metadatos Área

## ACUACAR

Los datos con los cuales se entreno el modelo tienen la siguiente
estructura:

### Entrada

#### Metadatos

-   Modo
-   Entrada  
-   code
-   name
-   CodigoTipoDocumental
-   NombreTipoDocumental
-   CodigoPadre
-   NombrePadre
-   CodigoAbuelo
-   NombreAbuelo
-   AREA
-   CodigoSerieDocumental
-   NombreSerieDocumental
-   dateCreated
-   dateModified
-   author
-   EN EXPTE?
-   OrgInteresadaRemitente
-   OrgInteresadaDestinatario
-   DependenciaResponsable  
-   NombreFichero
-   ContentId
-   MimeType
-   size
-   path

De estos se requiere obligatoriamente la variable AREA

#### Texto

-   parser
-   path
-   text
-   pages
-   document code

De estos se requiere obligatoriamente path y text

El modelo de área esta definido solo para mode de entrada, excluyendo
autores automáticos (“acuacarweb”,“pqrweb”,“admin”, “partner”)

### Salidas

Al correr el modelo la primera vez, se producen los siguientes
resultados:

-   Un archivo con el binario del modelo (modelo\_1\_2.rds)

-   ficha\_mod\_1\_2.csv: La ficha con las métricas del modelo.

-   matriz\_confusion\_mod\_1\_2.csv: El archivo con la matriz de
    confusión.

Al correr el modelo para generar predicciones con nuevos datos se
obtiene:

-   archivo de resultados (.csv), con el nombre dado. Tiene los
    siguientes campos:

    -   .pred\_class: El área con mayor probabilidad de predicción entre
        las 14 areas consideradas

    -   .pred\_xxxx: probabilidad de que el documento sea del área xxxx

------------------------------------------------------------------------

# PASOS

**1. Restaurar el entorno del modelo**

Este paso es necesario siempre.

    Rscript -e 'renv::restore()'

**2. Generar el binario del modelo**

Este paso es necesario solo si es la **primera vez** que el modelo de
corre en este computador. Es el paso de entrenar el modelo y obtener las
métricas relevantes. Por tanto, requiere que en el mismo directorio en
donde se encuentra el script esten los datos en una carpeta así:

-   “datos/ACUACAR\_Activo\_2020\_06\_01\_A\_2021\_02\_10\_V1.xlsx”.
-   “datos/acuacar.feather”

<!-- -->

    Rscript modelo_1_2.R

Como resultado se obtendrán los siguientes:

-   Un archivo con el binario del modelo (modelo\_1\_2.rds)
-   ficha\_mod\_1\_2.csv: La ficha con las métricas del modelo.
-   matriz\_confusion\_mod\_1\_2.csv: El archivo con la matriz de
    confusión.

**3. Generar datos de prueba**

Este paso es necesario solo en las pruebas. Los datos de ejemplo son
sustituidos por nuevos datos en producción

    Rscript generar_datos_ejemplo_1_2.R 1

**4. Ejecutar el modelo con nuevos datos**

Este es el comando principal para correr nuevos datos con el modelo que
debe ser llamado desde el servicio

    Rscript modelo_servido_1_2.R <archivo csv metadatos nuevos datos> 
    <archivo feather nuevos textos> <archivo csv resultados>

Ejemplo:

    Rscript modelo_servido_1_2.R muestra_1_2.csv datos/acuacar.feather resultado_mod_1_2.csv
