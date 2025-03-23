
library("readxl")
library("lmtest")
library("tseries")
library("tidyverse")
library("urca")
library("forecast")
library("tsDyn")
library(vars)


#Getting the data

series <- read_excel("D:/Mestrado/Materias/Modelos macro/Trabalho final/estimating-brazilian-BEER/data/DADOS - cambio.xlsx")

#Transforming the variables into time series and plotting each one of them

#exchange rate
cambio <- ts(serie$CAMBIO, start = c(2013,1), end = c(2019,12), frequency = 253)
plot(cambio, type = "l", main = "cambio")

#credit default swap 
cds <- ts(log(serie$CDS), start = c(2013,1), end = c(2019,12), frequency = 253)
plot(cds, type = "l", main = "cds")

#CRB index - proxy for commodity prices 
crb <- ts(log(serie$CRB), start = c(2013,1), end = c(2019,12), frequency = 253)
plot(crb, type = "l", main = "crb")

# DXY - index of dollar against other major currencies
dxy <- ts(log(serie$DXY), start = c(2013,1), end = c(2019,12), frequency = 253)
plot(dxy, type = "l", main = "dxy")

#Interest rate differential between Brazil and US
diferenca_juros <- ts(serie$DIF, start = c(2013,1), end = c(2019,12), frequency = 253)
plot(diferenca_juros, type = "l", main = "Diferencial de juros")



#Unit root test for stationarity
#Augmented Dickey-Fuller (ADF) 
# H0: the series has a unit root (non-stationary)
# H1: no unit root (stationary) 
# Comparing the p-value with 0.05 (if it's greater, do not reject H0)
# A high p-value supports failing to reject H0 (non-stationarity)
adf.test(cambio)
adf.test(cds)
adf.test(crb)
adf.test(dxy)
adf.test(diferenca_juros)


# Creating a dataset
dset <- cbind(cambio, cds, crb, dxy, diferenca_juros)


########### Creating a Vector Autoregressive Model (VAR)

#VAR order
defasagem_var <- VARselect(dset, lag.max = 50, type = "const")
defasagem_var$selection  

#Estimating the VAR
modelo_VAR <- VAR(dset, p=2, type = "const")
summary(modelo_VAR)

#VAR diagnosis
roots(modelo_VAR) #all the roots within the unit circle
#serial.test(modelo_VAR, type = "PT.asymptotic")

#Breusch-Godfrey test for serial correlation
serial.test(modelo_VAR, type = "BG")  ###
#serial.test(modelo_VAR, type = "ES")

#Normality test for the residuals
normality.test(modelo_VAR, multivariate.only = TRUE)  ### teste de normalidade dos residuos
acf(residuals(modelo_VAR))



##### Johansen test for cointegration 

# Applying the test
ctest <- ca.jo(dset, type = "trace", ecdet = "const", K = 2, spec = "longrun")
summary(ctest)

# First, it's possible to reject the hypothesis for no cointegration(r = 0). Therefore, there's some cointegration vector.(r = rank = posto da matriz)
# But it's not possible to reject r<=1. So, there's only one cointegration vector. (r=1)


# Creating a VECM
modelo <- VECM(dset, lag = 2, r = 1, estim = "2OLS", include = c("const")) 
summary(modelo)


# Plotting the VECM graph alongside the exchange rate
#BEER <-  +0.57*cds  -1.65*crb +2.12*dxy -0.05*diferenca_juros
BEER <-  +1.06*cds  -1.26*crb +1.07*dxy -0.07*diferenca_juros
plot(BEER, type = "l", col = "red", main = "BRL vs BEER", ylab = "Exchange rate", xlab = "Years")
lines(cambio, type = "l", col = "blue")
legend("topleft", c("BEER", "BRL"), lty = 1, col =c("red", "blue"))


#Plotting the VECM residuals
plotres(ctest)

# Transforming the VECM in a VAR. (Precisa fazer isso para fazer os testes no modelo)
modelo_var <- vec2var(ctest, r =1)

#Impulse response function
#How CDS affects the exchange rate

par(mfrow=c(2,2))

cds_impulso <- irf(modelo_var, impulse = "cds", response = "cambio", n.ahead = 20, boot = TRUE)
plot(cds_impulso, ylab = "Cambio", main = "Choque do CDS no cambio")

#How CRB affects the exchange rate
crb_impulso <- irf(modelo_var, impulse = "crb", response = "cambio", n.ahead = 20, boot = TRUE)
plot(crb_impulso, ylab = "Cambio", main = "Choque do CRB no cambio")

#How DXY affects the exchange rate
dxy_impulso <- irf(modelo_var, impulse = "dxy", response = "cambio", n.ahead = 20, boot = TRUE)
plot(dxy_impulso, ylab = "Cambio", main = "Choque do DXY no cambio")

#How the interest rate differential affects the exchange rate
diffJuros <- irf(modelo_var, impulse = "diferenca_juros", response = "cambio", n.ahead = 20, boot = TRUE)
plot(diffJuros, ylab = "Cambio", main = "Choque do diferencial de juros no cambio")

par(mfrow=c(1,1))

# Variance decomposition
decom <- fevd(modelo_var, n.ahead = 20)
plot(decom)

