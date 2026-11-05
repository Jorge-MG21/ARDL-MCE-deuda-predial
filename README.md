# ARDL-MCE: Deuda predial e inversion publica (MDJLO 2018-2025)

Analisis de la incidencia de la deuda predial pendiente de cobro y la morosidad sobre la ejecucion de la inversion publica de la Municipalidad Distrital de Jose Leonardo Ortiz.

## Archivos

| Archivo | Descripcion |
|---------|-------------|
| `ardl_mce_analisis.R` | Script ARDL + MCE con 6 especificaciones alternativas |
| `data/Nueva_dta_2018_2025.csv` | Datos mensuales 2018-2025 (parcial; completar con Excel) |
| `resultados/RESULTADOS_Y_ANALISIS_ARDL.md` | **Informe completo de resultados preliminares, metodologia, criterios de decision y guia de interpretacion** |

## Como ejecutar

1. Coloca `Nueva_dta.xlsx` (Hoja1) en la carpeta del script o en `data/`.
2. En R:

```r
source("ardl_mce_analisis.R")
# o desde terminal:
# Rscript ardl_mce_analisis.R Nueva_dta.xlsx salida_ARDL
```

## Especificaciones

- **M1** Original (nivel de deuda)
- **M2** Delta ln(deuda)
- **M3** Ratio deuda/PIM
- **M4** Tasa de ejecucion como dependiente
- **M5** Parsimonioso
- **M6** Ratio + tasa de ejecucion

El script reporta explicitamente si cada modelo apoya o no la hipotesis de un efecto **negativo y significativo** de la deuda/morosidad sobre la ejecucion de la inversion.

## Resultados y toma de decisiones

Ver el informe detallado en:
**[resultados/RESULTADOS_Y_ANALISIS_ARDL.md](resultados/RESULTADOS_Y_ANALISIS_ARDL.md)**

Incluye:
- Analisis descriptivo de los datos parciales disponibles
- Criterios explicitos para decidir si un modelo apoya la hipotesis
- Escenarios de interpretacion y acciones recomendadas
- Proximos pasos priorizados para completar la investigacion

## Datos

- Fuente: registros municipales MDJLO + MEF + SATJLO
- Periodo: enero 2018 - diciembre 2025 (96 obs. mensuales)
- Variables clave: deuda, recaudacion, devengado, foncomun, pim, Morosidad

**Nota importante:** El CSV actual solo contiene 2018-2019 (24 obs.). Sube el Excel completo (`Nueva_dta.xlsx`) a la carpeta `data/` desde la interfaz web de GitHub para poder ejecutar el analisis ARDL completo y actualizar los resultados.
