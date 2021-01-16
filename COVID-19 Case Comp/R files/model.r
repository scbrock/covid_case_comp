library(ggplot2)
library(data.table)
library(mgcv)
library(dplyr)

# Helper functions to create aggregated case counts and mobility
# 7-day rolling sum of new cases of vector x
rs7 = function(x) {
    rs = rep(NA, length(x))
    j = 1
    while(is.na(x[j]) & j < length(x)) {
        j = j + 1
    }
    for (i in (j + 6): length(x)) {
        rs[i] = sum(x[(i-6): i])
    }
    return(rs)
}

# 7-day simple moving average of vector x
sma7 = function(x) {
    avg = rep(NA, length(x))
    for (i in 7: length(x)) {
        avg[i] = mean(x[(i-6): i])
    }
    return(avg)
}

# shift indices of vector x by n places
shift_n = function(x, n) {
    m = length(x)
    shifted_x = rep(NA, m)
    if (n > 0) {
        shifted_x[1:(m - n)] = x[(n+1):m]
    } else {
        shifted_x[-1:n] = x[1:(m+n)]
    }
    return(shifted_x)
}

path = file.path("..", "Datasets", "full_data.csv")
data = read.csv(path)
data$date = as.Date(data$date)

# create new variables of 7-day rolling sums for new case
# counts with varying lags
data = data %>%
    group_by(region) %>%
        mutate(new_rs = rs7(new_cases),
               rsf7 = rs7(shift_n(new_cases, 7)),
               rsp1 = rs7(shift_n(new_cases, -1)),
               rsp2 = rs7(shift_n(new_cases, -2)),
               rsp3 = rs7(shift_n(new_cases, -3)),
               rsp4 = rs7(shift_n(new_cases, -4)),
               rsp5 = rs7(shift_n(new_cases, -5)),
               rsp6 = rs7(shift_n(new_cases, -6)),
               rsp7 = rs7(shift_n(new_cases, -7)))
# update mobility variables to be 7-day simple moving averages
data$retail.rec = sma7(data$retail.rec)
data$grocery.pharm = sma7(data$grocery.pharm)
data$parks = sma7(data$parks)
data$transit = sma7(data$transit)
data$residential = sma7(data$residential)
data$workplaces = sma7(data$workplaces)

data = data.table(data)

# PCA
names(data)
mobility <- names(data)[8:13]
cases <- grep("rs", names(data), value=T)

ids <- which(apply(!is.na(data[,..mobility]),1,all))
pca_mobility <- princomp(data[ids,..mobility], cor = T)
plot(pca_mobility) # Visualize explained variance
pca_mobility$loadings

# check cumulative explained variance contribution of components 
cumsum(pca_mobility$sdev^2)/sum(pca_mobility$sdev^2)

# create PCA variables
data[ids, pca1 := pca_mobility$scores[,1]]
data[ids, pca2 := pca_mobility$scores[,2]]

# Formula
formula <- rsf7 ~ s(new_rs, k = 6) + s(rsp2, k = 6) + s(rsp4, k = 6) + s(rsp6, k = 6) +
    s(rsp7, k = 6) + population:pca1 + population:pca2 + region

# remove NA's from data
id <- which(apply(!is.na(cbind(data[,..mobility],data[,..cases])), 1, all))
data2 <- data[id,]

# Negative Binomial GAM
nb_mod <- gam(formula, data2, family = nb(link="identity"))
summary(nb_mod)

# plot smooth effects
plot(nb_mod, residuals = T)

# check diagnostics
gam.check(nb_mod)

AIC(nb_mod)

# Poisson GAM

pois_mod <- gam(formula, data2, family = "poisson")
summary(pois_mod)

# plot smooth effects
plot(pois_mod, residuals = T)

# check diagnostics
gam.check(pois_mod)

AIC(pois_mod)
