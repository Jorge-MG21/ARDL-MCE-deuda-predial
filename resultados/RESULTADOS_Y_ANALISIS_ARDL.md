# Resultados y Análisis ARDL + MCE  
## Incidencia de la deuda predial y la morosidad sobre la ejecución de la inversión pública  
### Municipalidad Distrital de José Leonardo Ortiz (MDJLO) — 2018-2025

**Fecha de generación:** 2026-11-05  
**Repositorio:** [Jorge-MG21/ARDL-MCE-deuda-predial](https://github.com/Jorge-MG21/ARDL-MCE-deuda-predial)  
**Script fuente:** `ardl_mce_analisis.R`

---

## 1. Estado de los datos y limitaciones críticas

### Datos disponibles en el repositorio
El archivo `data/Nueva_dta_2018_2025.csv` contiene **solo 24 observaciones mensuales** (enero 2018 – diciembre 2019).  

El script original y el README esperan **96 observaciones** (2018-2025 completo).  

| Limitación | Impacto en el análisis |
|------------|------------------------|
| N = 24 | Insuficiente para ARDL con órdenes de rezago hasta 3 (se pierden grados de libertad; estimaciones inestables) |
| Falta 2020-2025 | No se puede evaluar el efecto COVID, recuperación post-pandemia ni periodos recientes de mayor deuda |
| No hay Excel completo | El script está diseñado para `Nueva_dta.xlsx` (Hoja1) |

**Recomendación prioritaria para la investigación:**  
Subir el archivo Excel completo (`Nueva_dta.xlsx`) a la carpeta `data/` del repositorio. Una vez disponible, se puede re-ejecutar el script completo y actualizar este informe.

---

## 2. Análisis descriptivo preliminar (datos 2018-2019)

### Resumen estadístico

| Variable | Min | 1er Cuartil | Mediana | Media | 3er Cuartil | Máx |
|----------|-----|-------------|---------|-------|-------------|-----|
| Deuda predial | 14.18 M | 14.56 M | 15.17 M | 15.13 M | 15.61 M | 16.13 M |
| Recaudación | 332k | 373k | 415k | 517k | 702k | 838k |
| Devengado (inversión) | 281k | 371k | 447k | 544k | 494k | 1.83 M |
| Foncomun | 1.82 M | 1.90 M | 1.94 M | 1.97 M | 2.05 M | 2.22 M |
| PIM | 6.08 M | 6.63 M | 6.90 M | 6.95 M | 7.32 M | 7.90 M |
| Morosidad (%) | 18.13 | 20.76 | 37.01 | 32.32 | 39.52 | 46.49 |

### Matriz de correlaciones (2018-2019)

| | Deuda | Recaudación | Devengado | Foncomun | PIM | Morosidad |
|---|-------|-------------|-----------|----------|-----|-----------|
| **Deuda** | 1.00 | 0.15 | 0.37 | 0.68 | 0.78 | -0.06 |
| **Recaudación** | 0.15 | 1.00 | -0.13 | 0.07 | 0.22 | **-0.98** |
| **Devengado** | 0.37 | -0.13 | 1.00 | 0.26 | 0.53 | 0.12 |
| **Foncomun** | 0.68 | 0.07 | 0.26 | 1.00 | 0.43 | -0.01 |
| **PIM** | 0.78 | 0.22 | 0.53 | 0.43 | 1.00 | -0.16 |
| **Morosidad** | -0.06 | **-0.98** | 0.12 | -0.01 | -0.16 | 1.00 |

**Hallazgos preliminares:**
- La morosidad está casi perfectamente correlacionada de forma negativa con la recaudación (r = −0.98). Esto es coherente teóricamente: mayor morosidad → menor recaudación efectiva.
- La deuda predial muestra correlación positiva moderada-alta con el PIM (0.78) y con Foncomun (0.68). Esto sugiere que el stock de deuda crece junto con el tamaño del presupuesto.
- La correlación simple entre deuda y devengado es positiva (0.37), lo cual **no apoya a priori** la hipótesis de efecto negativo. Sin embargo, correlaciones simples no controlan por variables confusoras ni dinámicas de corto/largo plazo.

### Gráficos generados

1. **01_series_principales.png** — Evolución temporal de deuda, devengado, morosidad y tasa de ejecución (2018-2019).
2. **02_scatter_relaciones.png** — Dispersión y rectas de regresión simple entre las variables clave.

Estos gráficos se encuentran en la carpeta `resultados/` del repositorio.

---

## 3. Metodología ARDL + MCE implementada en el script

El script `ardl_mce_analisis.R` implementa un enfoque de **robustez** con **6 especificaciones alternativas**, siguiendo las recomendaciones de Pesaran, Shin & Smith (2001) y la literatura de modelos ARDL-Bounds Testing.

### Hipótesis de investigación
> La deuda predial pendiente de cobro y/o la morosidad tienen un **efecto negativo y estadísticamente significativo** sobre la ejecución de la inversión pública (en el corto y/o en el largo plazo).

### Criterios de decisión explícitos del script
Para que un modelo **apoye la hipótesis** se requiere simultáneamente:

1. Coeficiente de largo plazo de la variable de deuda (o ratio) **negativo**.
2. Significancia estadística del coeficiente de LP (p < 0.05).
3. Error de corrección (ECT) en el rango **−1 < ρ < 0** y significativo al 5 %.
4. (Adicionales de calidad) Diagnósticos de residuales aceptables (BG, JB, BP, CUSUM).

Si **ninguna** de las 6 especificaciones cumple los tres primeros criterios, el script reporta explícitamente:

> “NINGUNA de las especificaciones estimadas aporta evidencia estadística a favor de un efecto negativo y significativo…”

Esto es una buena práctica de **transparencia científica**.

### Las 6 especificaciones

| Modelo | Variable dependiente | Variable de deuda | Controles principales | Justificación teórica |
|--------|----------------------|-------------------|-----------------------|-----------------------|
| **M1** | ln(devengado) | ln(deuda) | recaudación, foncomun, PIM, monto viable | Especificación original de referencia (nivel de stock) |
| **M2** | ln(devengado) | Δln(deuda) | recaudación, foncomun, PIM | La variación del stock es más cercana a un flujo |
| **M3** | ln(devengado) | ln(deuda/PIM) | recaudación, foncomun | Carga relativa de la deuda sobre el presupuesto |
| **M4** | ln(tasa ejecución) | ln(deuda) | recaudación, foncomun | Normaliza la ejecución por el tamaño del presupuesto |
| **M5** | ln(devengado) | ln(deuda) | foncomun + dummies | Parsimonioso (reduce colinealidad) |
| **M6** | ln(tasa ejecución) | ln(deuda/PIM) | foncomun + dummies | Combina ratio + tasa de ejecución |

Todas incluyen como regresores fijos (no se seleccionan rezagos): Morosidad, DUMMIE_COVID, DUMMIE_Est, n_proyectos_viab y/o D_dic (dummy de diciembre, por el comportamiento estacional de cierre de año).

### Procedimiento técnico de cada modelo
1. Selección automática de órdenes de rezago con **BIC** (máximo orden 3).
2. Estimación del ARDL.
3. **Bounds F-test** y **Bounds t-test** (case = 3: unrestricted intercept, no trend).
4. Transformación a forma de **Modelo de Corrección de Error (MCE)** vía `recm()`.
5. Extracción del ECT y verificación del rango teórico (−1, 0).
6. Multiplicadores de largo plazo (`multipliers()`).
7. Diagnósticos:
   - Breusch-Godfrey (autocorrelación) órdenes 1, 4 y 12
   - Jarque-Bera (normalidad)
   - Breusch-Pagan (heterocedasticidad)
   - CUSUM recursivo y OLS-CUSUM (estabilidad estructural)

---

## 4. Cómo interpretar los resultados cuando se tenga el dataset completo

### Tabla resumen que generará el script
El script produce una tabla comparativa con las siguientes columnas clave:

- `Modelo`
- `ECT` y `ECT_en_rango` (TRUE/FALSE)
- `Coef_LP_deuda` y `p_LP_deuda`
- `Signo_negativo` / `Significativo` / `Apoya_hipotesis`
- Indicadores de diagnóstico (BG_ok, JB_ok, BP_ok, CUSUM_ok)

### Escenarios posibles y decisión de investigación

| Escenario | Interpretación para la investigación | Acción recomendada |
|-----------|--------------------------------------|--------------------|
| **Varias especificaciones apoyan** (Apoya_hipotesis = TRUE) | Evidencia robusta de efecto negativo de la deuda/morosidad | Reportar el modelo principal (preferiblemente M1 o M3) + robustez. Discutir magnitud del multiplicador de LP y velocidad de ajuste (ECT). |
| **Solo 1-2 especificaciones apoyan** | Evidencia débil / sensible a la forma funcional | Reportar con cautela. Realizar análisis de sensibilidad adicional (cambiar max_order, selection = AIC, incluir/excluir dummies). |
| **Ninguna apoya** | No hay evidencia estadística de efecto negativo significativo | **Reportar con transparencia**. Explorar hipótesis alternativas: (a) la deuda es consecuencia y no causa de baja ejecución; (b) efecto no lineal (umbrales); (c) variables omitidas (capacidad institucional, personal, etc.). |
| **ECT fuera de rango o no significativo** | No hay cointegración / no hay mecanismo de corrección de error válido | Descartar la especificación para inferencia de largo plazo. Considerar modelos en diferencias o VAR. |
| **Diagnósticos fallan (BG o CUSUM)** | Residuos problemáticos o inestabilidad estructural | Re-especificar (más/menos rezagos, variables dummy de quiebre, o modelo con breaks). |

### Magnitud económica
Además de la significancia estadística, se debe evaluar:
- El **multiplicador de largo plazo**: ¿un aumento de 1 % en la deuda reduce la ejecución en X %?
- La **velocidad de ajuste** (|ECT|): si |ρ| = 0.25 → se corrige el 25 % del desequilibrio cada mes → ajuste relativamente rápido.

---

## 5. Próximos pasos recomendados (orden de prioridad)

1. **Completar los datos**  
   Subir `Nueva_dta.xlsx` completo (2015 o 2018 – 2025) a `data/`.

2. **Re-ejecutar el script**  
   ```r
   source("ardl_mce_analisis.R")
   # o desde terminal:
   Rscript ardl_mce_analisis.R data/Nueva_dta.xlsx resultados/
   ```

3. **Revisar la tabla `Resumen_modelos`** y el archivo `resultados_ARDL_MCE_robustez.xlsx`.

4. **Seleccionar el modelo principal** según:
   - Apoyo a la hipótesis
   - Calidad de diagnósticos
   - Coherencia teórica (preferir M3 o M6 si el ratio es conceptualmente superior al nivel de deuda)

5. **Documentar en el artículo/tesis**:
   - Resultados de las 6 especificaciones (tabla comparativa)
   - Gráficos de series, CUSUM y residuales del modelo elegido
   - Interpretación económica de los multiplicadores de LP y del ECT
   - Limitaciones (posible endogeneidad, medición de morosidad, etc.)

6. **Análisis complementarios sugeridos** (si el ARDL no apoya la hipótesis):
   - Pruebas de causalidad de Granger / Toda-Yamamoto
   - Modelos de umbral (TAR / threshold ARDL)
   - Variables instrumentales si se sospecha endogeneidad
   - Análisis a nivel de proyectos (no solo agregado mensual)

---

## 6. Estructura de archivos generados por el script (cuando se ejecute con datos completos)

```
salida_ARDL/   (o resultados/)
├── resultados_consola_ARDL.txt          # Log completo de estimaciones
├── resultados_ARDL_MCE_robustez.xlsx    # Tablas ADF + resumen + coeficientes LP y MCE
├── modelos_ARDL_MCE.RData               # Objetos R guardados
├── 01_series_principales.png
├── 02_diagnostico_mce.png
└── 03_residuos.png
```

---

## 7. Conclusión provisional (basada en datos parciales 2018-2019)

Con los 24 meses disponibles:
- La correlación simple no muestra una relación negativa entre deuda y ejecución.
- Existe una relación casi perfecta entre morosidad y recaudación (negativa).
- El tamaño de muestra impide cualquier conclusión confiable de cointegración o efectos de largo plazo.

**La decisión de investigación depende enteramente de la re-ejecución con el dataset completo 2018-2025.**  
Este informe y los gráficos preliminares sirven como base metodológica y de documentación transparente del proceso.

---

*Generado automáticamente para facilitar la toma de decisiones en la investigación.  
Una vez se suba el Excel completo, se puede actualizar este documento con los resultados numéricos reales de las 6 especificaciones ARDL.*
