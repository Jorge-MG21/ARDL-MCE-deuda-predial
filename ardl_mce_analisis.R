# =====================================================================
# ARDL + MCE  -  Incidencia de la deuda predial y la morosidad sobre la
# ejecucion de la inversion publica (MDJLO, 2018-2025)
# Datos: Nueva_dta.xlsx (Hoja1)
# =====================================================================
args    <- commandArgs(trailingOnly = TRUE)
ruta    <- ifelse(length(args) >= 1, args[1], "Nueva_dta.xlsx")
carpeta <- ifelse(length(args) >= 2, args[2], "salida_ARDL")
dir.create(carpeta, showWarnings = FALSE, recursive = TRUE)
install.packages(c("ARDL","readxl","writexl","tseries","lmtest","sandwich","strucchange","car"))
suppressMessages({
  library(readxl); library(writexl); library(tseries); library(ARDL)
  library(lmtest); library(sandwich); library(strucchange); library(car)
})
sink(file.path(carpeta, "resultados_consola_ARDL.txt"), split = TRUE)
png_<- function(nombre, w = 1400, h = 900) png(file.path(carpeta, nombre), width = w, height = h, res = 130)
while (sink.number() > 0) sink()   # cierra el sink abierto por el error anterior
ruta    <- "C:/Users/merag/OneDrive/Desktop/ULTIMO_BAILE/Nueva_dta.xlsx"
carpeta <- "C:/Users/merag/OneDrive/Desktop/ULTIMO_BAILE/salida_ARDL"
dir.create(carpeta, showWarnings = FALSE, recursive = TRUE)
# ---------------------------------------------------------------------
# 1. DATOS
# ---------------------------------------------------------------------
raw <- read_excel(ruta, sheet = "Hoja1")
names(raw) <- trimws(names(raw))                      # "Morosidad " -> "Morosidad"
raw <- as.data.frame(raw)
names(raw)[names(raw) == "a\u00f1os"]         <- "anio"
names(raw)[names(raw) == "deuda predial"]     <- "deuda"
# Serie mensual completa: ene-2015 a dic-2025 (132 obs). Periodo principal 2018-2025.
raw$mes  <- rep(1:12, length.out = nrow(raw))
raw$D_dic <- as.integer(raw$mes == 12)                # dummy de diciembre
datos <- raw[raw$anio >= 2018 & raw$anio <= 2025, ]
cat("Observaciones 2018-2025:", nrow(datos), "\n")
stopifnot(!anyNA(datos[, c("deuda","recaudacion","devengado","foncomun","pim","Morosidad")]),
          all(datos[, c("deuda","recaudacion","devengado","foncomun","pim")] > 0))
# Logaritmos (monto_viable tiene ceros en meses sin proyectos viables -> log(1 + x))
d <- data.frame(
  ln_devengado    = log(datos$devengado),
  ln_deuda        = log(datos$deuda),
  ln_recaudacion  = log(datos$recaudacion),
  ln_foncomun     = log(datos$foncomun),
  ln_pim          = log(datos$pim),
  ln_monto_viable = log1p(datos$monto_viable),
  Morosidad       = datos$Morosidad,
  DUMMIE_COVID    = datos$DUMMIE_COVID,
  DUMMIE_Est      = datos$DUMMIE_Est,
  n_proyectos_viab= datos$n_proyectos_viab,
  D_dic           = datos$D_dic
)
ts_d <- ts(d, start = c(2018, 1), frequency = 12)
png_("01_series_log.png")
plot(ts_d[, 1:6], main = "Series en logaritmos (2015-2025)", xlab = "Anio")
invisible(dev.off())
# ---------------------------------------------------------------------
# 2. RAICES UNITARIAS (ADF)
# ---------------------------------------------------------------------
adf_tabla <- function(x, nombre) {
  x <- as.numeric(x)
  p0 <- suppressWarnings(adf.test(x)$p.value)
  p1 <- suppressWarnings(adf.test(diff(x))$p.value)
  data.frame(variable = nombre, p_nivel = round(p0, 4), p_dif1 = round(p1, 4),
             orden = ifelse(p0 < 0.05, "I(0)", ifelse(p1 < 0.05, "I(1)", "posible I(2)")))
}
vars_adf <- c("ln_devengado","ln_deuda","ln_recaudacion","ln_foncomun","ln_pim",
              "ln_monto_viable","Morosidad")
tabla_adf <- do.call(rbind, lapply(vars_adf, function(v) adf_tabla(ts_d[, v], v)))
cat("\n=== ADF ===\n"); print(tabla_adf)
# ---------------------------------------------------------------------
# 3. SELECCION DE REZAGOS Y ARDL
#    Regresores de largo plazo (en la formula) | controles exogenos fijos
# ---------------------------------------------------------------------
f_ardl <- ln_devengado ~ ln_deuda + ln_recaudacion + ln_foncomun + ln_pim +
  ln_monto_viable | Morosidad + DUMMIE_COVID + DUMMIE_Est + n_proyectos_viab + D_dic
max_ord <- 3
t0 <- Sys.time()
sel_bic <- auto_ardl(f_ardl, data = ts_d, max_order = max_ord, selection = "BIC")
sel_aic <- auto_ardl(f_ardl, data = ts_d, max_order = max_ord, selection = "AIC")
cat("\nTiempo seleccion:", round(difftime(Sys.time(), t0, units = "mins"), 1), "min\n")
cat("Mejor orden BIC:", sel_bic$best_order, "\n")
cat("Mejor orden AIC:", sel_aic$best_order, "\n")
print(head(sel_bic$top_orders, 5))
orden <- sel_bic$best_order
if (!is.na(Sys.getenv("ORDEN", NA))) orden <- as.integer(strsplit(Sys.getenv("ORDEN"), ",")[[1]])
cat("Orden usado:", orden, "\n")
m_ardl <- ardl(f_ardl, data = ts_d, order = orden)
cat("\n=== ARDL ===\n"); print(summary(m_ardl))
# ---------------------------------------------------------------------
# 4. PRUEBA DE LIMITES (Pesaran, Shin y Smith, 2001) - caso 3
# ---------------------------------------------------------------------
bf <- bounds_f_test(m_ardl, case = 3); cat("\n=== Bounds F ===\n"); print(bf)
bt <- bounds_t_test(m_ardl, case = 3); cat("\n=== Bounds t ===\n"); print(bt)
# ---------------------------------------------------------------------
# 5. MCE
# ---------------------------------------------------------------------
m_ecm <- recm(m_ardl, case = 3)
cat("\n=== MCE ===\n"); print(summary(m_ecm))
tab <- coef(summary(m_ecm))
fila_ect <- grep("^ect", rownames(tab))
ect <- tab[fila_ect, , drop = FALSE]
cat("\nECT:", round(ect[1,1], 4), "| p =", round(ect[1,4], 4),
    "| negativo:", ect[1,1] < 0, "| signif 5%:", ect[1,4] < 0.05,
    "| -1<rho<0:", ect[1,1] > -1 && ect[1,1] < 0, "\n")
corto <- tab[-fila_ect, , drop = FALSE]
cat("\n--- Corto plazo ---\n"); print(round(corto, 4))
cat("\n--- Largo plazo (multiplicadores) ---\n")
lp <- multipliers(m_ardl); print(lp)
idx_d <- grep("ln_deuda", names(coef(m_ecm)))
if (length(idx_d) > 0) {
  R <- diag(length(coef(m_ecm)))[idx_d, , drop = FALSE]
  cat("\n--- Wald conjunto corto plazo ln_deuda ---\n")
  print(linearHypothesis(m_ecm, hypothesis.matrix = R, rhs = rep(0, length(idx_d))))
}
# ---------------------------------------------------------------------
# 6. DIAGNOSTICOS
# ---------------------------------------------------------------------
res <- residuals(m_ecm)
bg <- lapply(c(1, 4, 12), function(o) { cat("\nBreusch-Godfrey orden", o, "\n"); r <- bgtest(m_ecm, order = o); print(r); r })
jb <- jarque.bera.test(as.numeric(res)); print(jb)
bp <- bptest(m_ecm); print(bp)
hac_df <- NULL
if (bp$p.value < 0.05) {
  cat("\nHeteroscedasticidad -> EE Newey-West\n")
  hac <- coeftest(m_ecm, vcov = NeweyWest(m_ecm, prewhite = FALSE)); print(hac)
  hac_df <- data.frame(termino = rownames(hac), hac[, 1:4], check.names = FALSE)
}
diag_df <- data.frame(
  prueba = c("BG orden 1","BG orden 4","BG orden 12","Jarque-Bera","Breusch-Pagan"),
  estadistico = round(c(sapply(bg, function(r) r$statistic), jb$statistic, bp$statistic), 4),
  p_valor = round(c(sapply(bg, function(r) r$p.value), jb$p.value, bp$p.value), 4))
diag_df$conclusion_5pct <- ifelse(diag_df$p_valor > 0.05, "No se rechaza H0 (OK)", "Se rechaza H0")
cat("\n=== Resumen diagnosticos ===\n"); print(diag_df)
# ---------------------------------------------------------------------
# 7. GRAFICOS
# ---------------------------------------------------------------------
png_("02_diagnostico_mce.png"); op <- par(mfrow = c(2,2)); plot(m_ecm); par(op); invisible(dev.off())
png_("03_residuos.png"); op <- par(mfrow = c(1,3))
plot(as.ts(res), main = "Residuos MCE", ylab = "", xlab = "Anio"); abline(h = 0, lty = 2)
acf(as.numeric(res), lag.max = 24, main = "ACF residuos"); hist(as.numeric(res), breaks = 15, main = "Histograma", xlab = "")
par(op); invisible(dev.off())
fit <- as.ts(fitted(m_ardl)); act <- window(ts_d[, "ln_devengado"], start = start(fit), end = end(fit))
png_("04_fitted_vs_actual_ardl.png")
ts.plot(act, fit, col = c("black","red"), lwd = 2, main = "ARDL: ln_devengado real vs ajustado", ylab = "ln(devengado)")
legend("topleft", c("Actual","Ajustado"), col = c("black","red"), lwd = 2, bty = "n"); invisible(dev.off())
fe <- as.ts(fitted(m_ecm))
png_("05_fitted_vs_actual_mce.png")
ts.plot(fe + as.ts(res), fe, col = c("black","blue"), lwd = 2, main = "MCE: D.ln_devengado real vs ajustado")
legend("topleft", c("Actual","Ajustado"), col = c("black","blue"), lwd = 2, bty = "n"); invisible(dev.off())
# CUSUM (5%) sobre la regresion del MCE (residuos recursivos) + CUSUMSQ
X <- model.matrix(m_ecm); y <- model.response(model.frame(m_ecm))
cus <- efp(y ~ X - 1, type = "Rec-CUSUM")
cussq <- efp(y ~ X - 1, type = "OLS-CUSUM")
png_("06_cusum.png", 1400, 700); op <- par(mfrow = c(1,2))
plot(cus, main = "CUSUM recursivo (5%)"); plot(cussq, main = "OLS-CUSUM (5%)"); par(op); invisible(dev.off())
cus_p  <- sctest(cus);  cat("\nCUSUM recursivo p =", round(cus_p$p.value, 4), "\n")
ocus_p <- sctest(cussq); cat("OLS-CUSUM p =", round(ocus_p$p.value, 4), "\n")
# ---------------------------------------------------------------------
# 8. EXPORTAR
# ---------------------------------------------------------------------
lp_df <- as.data.frame(lp); lp_df <- cbind(termino = rownames(lp_df), lp_df)
tablas <- list(
  ADF = tabla_adf,
  Bounds = data.frame(prueba = c("F","t"), estadistico = c(bf$statistic, bt$statistic),
                      p_valor = c(bf$p.value, bt$p.value)),
  Velocidad_ajuste = data.frame(termino = rownames(ect), ect, check.names = FALSE),
  Corto_plazo = data.frame(termino = rownames(corto), corto, check.names = FALSE),
  Largo_plazo = lp_df,
  Diagnosticos = diag_df,
  ARDL_coef = data.frame(termino = rownames(coef(summary(m_ardl))), coef(summary(m_ardl)), check.names = FALSE))
if (!is.null(hac_df)) tablas$MCE_HAC_NeweyWest <- hac_df
write_xlsx(tablas, file.path(carpeta, "resultados_ARDL_MCE.xlsx"))
save(m_ardl, m_ecm, ts_d, file = file.path(carpeta, "modelos_ARDL_MCE.RData"))
sink()
cat("\nListo. Resultados en:", carpeta, "\n")
