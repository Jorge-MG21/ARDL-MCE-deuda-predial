# =====================================================================
# ARDL + MCE  -  Incidencia de la deuda predial y la morosidad sobre la
# ejecución de la inversión pública (MDJLO, 2018-2025)
#
# Versión mejorada:
#   - Varias especificaciones teóricas alternativas
#   - Variables transformadas (Δdeuda, ratio deuda/PIM, tasa de ejecución)
#   - Control del rango del ECT (-1 < ρ < 0)
#   - Reporte explícito de apoyo / no apoyo a la hipótesis
#   - Código limpio y portable
#
# Datos: Nueva_dta.xlsx (Hoja1)
# =====================================================================

args    <- commandArgs(trailingOnly = TRUE)
ruta    <- ifelse(length(args) >= 1, args[1], "Nueva_dta.xlsx")
carpeta <- ifelse(length(args) >= 2, args[2], "salida_ARDL")
dir.create(carpeta, showWarnings = FALSE, recursive = TRUE)

# Paquetes (solo instala si faltan)
pkgs <- c("ARDL", "readxl", "writexl", "tseries", "lmtest", "sandwich", "strucchange", "car")
for (p in pkgs) if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
suppressMessages({
  library(readxl); library(writexl); library(tseries); library(ARDL)
  library(lmtest); library(sandwich); library(strucchange); library(car)
})

sink(file.path(carpeta, "resultados_consola_ARDL.txt"), split = TRUE)
png_ <- function(nombre, w = 1400, h = 900)
  png(file.path(carpeta, nombre), width = w, height = h, res = 130)

# --------------------------------------------------------------------- 
# 1. DATOS
# --------------------------------------------------------------------- 
raw <- read_excel(ruta, sheet = "Hoja1")
names(raw) <- trimws(names(raw))
raw <- as.data.frame(raw)

# Estandarizar nombres
names(raw)[names(raw) %in% c("años", "años", "anios")] <- "anio"
names(raw)[names(raw) == "deuda predial"] <- "deuda"

# Dummy de diciembre y filtro temporal
n_obs <- nrow(raw)
raw$mes  <- rep(1:12, length.out = n_obs)
raw$D_dic <- as.integer(raw$mes == 12)

datos <- raw[raw$anio >= 2018 & raw$anio <= 2025, ]
cat("Observaciones 2018-2025:", nrow(datos), "\n")

# Validaciones básicas
vars_pos <- c("deuda", "recaudacion", "devengado", "foncomun", "pim")
stopifnot(!anyNA(datos[, c(vars_pos, "Morosidad")]),
          all(datos[, vars_pos] > 0))

# --------------------------------------------------------------------- 
# 2. CONSTRUCCIÓN DE VARIABLES
# --------------------------------------------------------------------- 
# Teoría:
#   - Deuda es stock → se usan nivel, variación y ratio sobre PIM
#   - Ejecución es flujo → se modela en log y también como tasa (devengado/PIM)
#   - Morosidad ya es una tasa

d <- data.frame(
  # Variable dependiente principal
  ln_devengado     = log(datos$devengado),
  # Alternativa: tasa de ejecución presupuestal
  tasa_ejecucion   = datos$devengado / datos$pim,
  ln_tasa_ejec     = log(pmax(datos$devengado / datos$pim, 1e-8)),

  # Deuda (stock)
  ln_deuda         = log(datos$deuda),
  # Variación de la deuda (más cercana a un flujo)
  d_ln_deuda       = c(NA, diff(log(datos$deuda))),
  # Ratio deuda / PIM (carga relativa sobre el presupuesto)
  ratio_deuda_pim  = datos$deuda / datos$pim,
  ln_ratio_deuda   = log(datos$deuda / datos$pim),

  # Controles de financiamiento
  ln_recaudacion   = log(datos$recaudacion),
  ln_foncomun      = log(pmax(datos$foncomun, 1)),   # protege ceros ocasionales
  ln_pim           = log(datos$pim),

  # Otras
  ln_monto_viable  = log1p(datos$monto_viable),
  Morosidad        = datos$Morosidad,
  DUMMIE_COVID     = datos$DUMMIE_COVID,
  DUMMIE_Est       = datos$DUMMIE_Est,
  n_proyectos_viab = datos$n_proyectos_viab,
  D_dic            = datos$D_dic,
  anio             = datos$anio,
  mes              = datos$mes
)

ts_d <- ts(d, start = c(2018, 1), frequency = 12)

png_("01_series_principales.png")
plot(ts_d[, c("ln_devengado", "ln_deuda", "ln_ratio_deuda", "Morosidad")],
     main = "Series principales (2018-2025)", xlab = "Año")
invisible(dev.off())

# --------------------------------------------------------------------- 
# 3. RAÍCES UNITARIAS (ADF)
# --------------------------------------------------------------------- 
adf_tabla <- function(x, nombre) {
  x  <- as.numeric(x)
  x  <- x[is.finite(x)]
  p0 <- tryCatch(suppressWarnings(adf.test(x)$p.value), error = function(e) NA)
  p1 <- tryCatch(suppressWarnings(adf.test(diff(x))$p.value), error = function(e) NA)
  data.frame(
    variable = nombre,
    p_nivel  = round(p0, 4),
    p_dif1   = round(p1, 4),
    orden    = ifelse(is.na(p0), "error",
               ifelse(p0 < 0.05, "I(0)",
               ifelse(!is.na(p1) & p1 < 0.05, "I(1)", "posible I(2)")))
  )
}

vars_adf <- c("ln_devengado", "ln_tasa_ejec", "ln_deuda", "d_ln_deuda",
              "ln_ratio_deuda", "ln_recaudacion", "ln_foncomun", "ln_pim",
              "Morosidad", "ln_monto_viable")
tabla_adf <- do.call(rbind, lapply(vars_adf, function(v) adf_tabla(ts_d[, v], v)))
cat("\n=== ADF ===\n"); print(tabla_adf)

# --------------------------------------------------------------------- 
# 4. FUNCIÓN AUXILIAR: estimar ARDL + MCE y reportar
# --------------------------------------------------------------------- 
estimar_modelo <- function(formula, data, max_ord = 3, nombre = "modelo",
                           case = 3, selection = "BIC") {
  cat("\n\n################################################################\n")
  cat("###  ", nombre, "\n")
  cat("################################################################\n")

  sel <- auto_ardl(formula, data = data, max_order = max_ord, selection = selection)
  orden <- sel$best_order
  cat("Orden seleccionado (", selection, "): ", paste(orden, collapse = ", "), "\n", sep = "")

  m_ardl <- ardl(formula, data = data, order = orden)
  cat("\n=== ARDL ===\n"); print(summary(m_ardl))

  bf <- bounds_f_test(m_ardl, case = case)
  bt <- bounds_t_test(m_ardl, case = case)
  cat("\n=== Bounds F ===\n"); print(bf)
  cat("\n=== Bounds t ===\n"); print(bt)

  m_ecm <- recm(m_ardl, case = case)
  cat("\n=== MCE ===\n"); print(summary(m_ecm))

  tab <- coef(summary(m_ecm))
  fila_ect <- grep("^ect", rownames(tab))
  ect_val  <- tab[fila_ect, 1]
  ect_p    <- tab[fila_ect, 4]

  cat("\nECT:", round(ect_val, 4),
      "| p =", round(ect_p, 4),
      "| negativo:", ect_val < 0,
      "| signif 5%:", ect_p < 0.05,
      "| -1 < ρ < 0:", ect_val > -1 && ect_val < 0, "\n")

  # Multiplicadores de largo plazo
  lp <- multipliers(m_ardl)
  cat("\n--- Largo plazo ---\n"); print(lp)

  # Diagnósticos
  res <- residuals(m_ecm)
  bg1  <- bgtest(m_ecm, order = 1)
  bg4  <- bgtest(m_ecm, order = 4)
  bg12 <- bgtest(m_ecm, order = 12)
  jb   <- jarque.bera.test(as.numeric(res))
  bp   <- bptest(m_ecm)

  cat("\nBreusch-Godfrey 1/4/12: p =",
      round(bg1$p.value, 3), "/", round(bg4$p.value, 3), "/", round(bg12$p.value, 3), "\n")
  cat("Jarque-Bera p =", round(jb$p.value, 3), "\n")
  cat("Breusch-Pagan p =", round(bp$p.value, 3), "\n")

  # CUSUM
  X <- model.matrix(m_ecm)
  y <- model.response(model.frame(m_ecm))
  cus  <- efp(y ~ X - 1, type = "Rec-CUSUM")
  cussq <- efp(y ~ X - 1, type = "OLS-CUSUM")
  cus_p  <- sctest(cus)$p.value
  ocus_p <- sctest(cussq)$p.value
  cat("CUSUM recursivo p =", round(cus_p, 4), "| OLS-CUSUM p =", round(ocus_p, 4), "\n")

  list(
    nombre   = nombre,
    ardl     = m_ardl,
    ecm      = m_ecm,
    orden    = orden,
    bounds_f = bf,
    bounds_t = bt,
    ect      = ect_val,
    ect_p    = ect_p,
    ect_ok   = ect_val > -1 && ect_val < 0 && ect_p < 0.05,
    lp       = lp,
    bg_p     = c(bg1$p.value, bg4$p.value, bg12$p.value),
    jb_p     = jb$p.value,
    bp_p     = bp$p.value,
    cusum_p  = cus_p,
    cussq_p  = ocus_p
  )
}

# --------------------------------------------------------------------- 
# 5. ESPECIFICACIONES
# --------------------------------------------------------------------- 
# Hipótesis: la deuda predial / morosidad tiene efecto NEGATIVO y significativo
# sobre la ejecución de la inversión (corto y/o largo plazo).

resultados <- list()

# ---- Modelo 1: Especificación original (referencia) -----------------
# ln_devengado ~ ln_deuda + controles | morosidad + dummies
f1 <- ln_devengado ~ ln_deuda + ln_recaudacion + ln_foncomun + ln_pim +
  ln_monto_viable | Morosidad + DUMMIE_COVID + DUMMIE_Est + n_proyectos_viab + D_dic
resultados[["M1_original"]] <- estimar_modelo(f1, ts_d, nombre = "M1 - Original (nivel de deuda)")

# ---- Modelo 2: Variación de la deuda (flujo) ------------------------
# Más coherente teóricamente: el cambio en el stock de deuda
f2 <- ln_devengado ~ d_ln_deuda + ln_recaudacion + ln_foncomun + ln_pim |
  Morosidad + DUMMIE_COVID + DUMMIE_Est + D_dic
resultados[["M2_delta_deuda"]] <- estimar_modelo(f2, ts_d, nombre = "M2 - Δ ln(deuda)")

# ---- Modelo 3: Ratio deuda / PIM ------------------------------------
# Carga relativa de la deuda sobre el presupuesto disponible
f3 <- ln_devengado ~ ln_ratio_deuda + ln_recaudacion + ln_foncomun |
  Morosidad + DUMMIE_COVID + DUMMIE_Est + D_dic
resultados[["M3_ratio"]] <- estimar_modelo(f3, ts_d, nombre = "M3 - Ratio deuda/PIM")

# ---- Modelo 4: Tasa de ejecución como dependiente -------------------
# Normaliza por el tamaño del presupuesto
f4 <- ln_tasa_ejec ~ ln_deuda + ln_recaudacion + ln_foncomun |
  Morosidad + DUMMIE_COVID + DUMMIE_Est + D_dic
resultados[["M4_tasa_ejec"]] <- estimar_modelo(f4, ts_d, nombre = "M4 - Tasa de ejecución")

# ---- Modelo 5: Parsimonioso (menos controles) -----------------------
# Reduce colinealidad
f5 <- ln_devengado ~ ln_deuda + ln_foncomun | Morosidad + D_dic
resultados[["M5_parsimonioso"]] <- estimar_modelo(f5, ts_d, nombre = "M5 - Parsimonioso")

# ---- Modelo 6: Ratio + tasa de ejecución ----------------------------
f6 <- ln_tasa_ejec ~ ln_ratio_deuda + ln_foncomun | Morosidad + D_dic
resultados[["M6_ratio_tasa"]] <- estimar_modelo(f6, ts_d, nombre = "M6 - Ratio + tasa ejecución")

# --------------------------------------------------------------------- 
# 6. RESUMEN COMPARATIVO Y EVALUACIÓN DE HIPÓTESIS
# --------------------------------------------------------------------- 
cat("\n\n################################################################\n")
cat("###  RESUMEN COMPARATIVO DE ESPECIFICACIONES\n")
cat("################################################################\n\n")

resumen <- do.call(rbind, lapply(resultados, function(r) {
  # Extraer coeficiente de largo plazo de la variable de deuda (si existe)
  lp <- r$lp
  idx_deuda <- grep("deuda|ratio", rownames(lp), ignore.case = TRUE)
  if (length(idx_deuda) > 0) {
    coef_lp  <- lp[idx_deuda[1], "Estimate"]
    p_lp     <- lp[idx_deuda[1], "Pr(>|t|)"]
    signo_ok <- coef_lp < 0
    sig_ok   <- p_lp < 0.05
  } else {
    coef_lp <- p_lp <- NA
    signo_ok <- sig_ok <- FALSE
  }

  data.frame(
    Modelo          = r$nombre,
    ECT             = round(r$ect, 3),
    ECT_en_rango    = r$ect_ok,
    Coef_LP_deuda   = round(coef_lp, 4),
    p_LP_deuda      = round(p_lp, 4),
    Signo_negativo  = signo_ok,
    Significativo   = sig_ok,
    Apoya_hipotesis = signo_ok && sig_ok && r$ect_ok,
    BG_ok           = all(r$bg_p > 0.05),
    JB_ok           = r$jb_p > 0.05,
    BP_ok           = r$bp_p > 0.05,
    CUSUM_ok        = r$cusum_p > 0.05
  )
}))

print(resumen)

cat("\n=== Evaluación de la hipótesis ===\n")
cat("Hipótesis: la deuda predial / morosidad tiene efecto NEGATIVO y significativo\n")
cat("sobre la ejecución de la inversión pública (corto y/o largo plazo).\n\n")

apoyan <- resumen$Modelo[resumen$Apoya_hipotesis]
if (length(apoyan) > 0) {
  cat("Especificaciones que APOYAN la hipótesis:\n")
  cat(paste(" -", apoyan), sep = "\n")
} else {
  cat("NINGUNA de las especificaciones estimadas aporta evidencia estadística\n")
  cat("a favor de un efecto negativo y significativo de la deuda/morosidad\n")
  cat("sobre la ejecución de la inversión pública.\n")
  cat("\nEsto debe reportarse con transparencia en la investigación.\n")
}

# --------------------------------------------------------------------- 
# 7. GRÁFICOS DEL MODELO PRINCIPAL (M1)
# --------------------------------------------------------------------- 
m_ecm <- resultados[["M1_original"]]$ecm
res   <- residuals(m_ecm)

png_("02_diagnostico_mce.png")
op <- par(mfrow = c(2, 2)); plot(m_ecm); par(op); invisible(dev.off())

png_("03_residuos.png")
op <- par(mfrow = c(1, 3))
plot(as.ts(res), main = "Residuos MCE", ylab = "", xlab = "Año"); abline(h = 0, lty = 2)
acf(as.numeric(res), lag.max = 24, main = "ACF residuos")
hist(as.numeric(res), breaks = 15, main = "Histograma", xlab = "")
par(op); invisible(dev.off())

# --------------------------------------------------------------------- 
# 8. EXPORTAR RESULTADOS
# --------------------------------------------------------------------- 
tablas <- list(
  ADF           = tabla_adf,
  Resumen_modelos = resumen
)

# Añadir coeficientes de cada modelo
for (nm in names(resultados)) {
  r <- resultados[[nm]]
  tablas[[paste0(nm, "_LP")]]  <- cbind(termino = rownames(r$lp), as.data.frame(r$lp))
  tablas[[paste0(nm, "_MCE")]] <- data.frame(
    termino = names(coef(r$ecm)),
    coef(summary(r$ecm)),
    check.names = FALSE
  )
}

write_xlsx(tablas, file.path(carpeta, "resultados_ARDL_MCE_robustez.xlsx"))
save(resultados, ts_d, file = file.path(carpeta, "modelos_ARDL_MCE.RData"))

sink()
cat("\nListo. Resultados en:", normalizePath(carpeta), "\n")
cat("Archivo principal de robustez: resultados_ARDL_MCE_robustez.xlsx\n")
