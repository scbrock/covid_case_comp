library(ggplot2)
library(data.table)
library(mgcv)
library(dplyr)

path = file.path("..", "Datasets", "full_data.csv")
data = read.csv(path)
data$date = as.Date(data$date)
colnames(data)

# create 7-day rolling sum of new cases
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
data = data.table(data)
write.csv(data, "full_data_rs7.csv")

#
# Model Negative Binomial GAM
#

# PCA
names(data)
mobility <- names(data)[8:13]
cases <- grep("rs", names(data), value=T)

ids <- which(apply(!is.na(data[,..mobility]),1,all))
pca_mobility <- princomp(data[ids,..mobility], cor = T)
plot(pca_mobility)
pca_mobility$loadings

data[ids, pca1 := pca_mobility$scores[,1]]
data[ids, pca2 := pca_mobility$scores[,2]]
data[ids, pca3 := pca_mobility$scores[,3]]

# Formula
formula <- rsf7 ~ s(new_rs, k = 6) + s(rsp2, k = 6) + s(rsp2, k = 6) + s(rsp6, k = 6) +
    s(rsp7, k = 6) + population:pca1 + population:pca2 + population:pca3 + pop_density + region

id <- which(apply(!is.na(cbind(data[,..mobility],data[,..cases])), 1, all))
data2 <- data[id,]

# Model
nb_mod <- gam(formula, data, family = nb(link="sqrt"))
summary(nb_mod)

# plot smooth effects
plot(nb_mod, residuals = T)

# check diagnostics
gam.check(nb_mod)

AIC(nb_mod)


#
#  ==============================  Discrete Case Count Data  ============================
#

path = file.path("..", "Datasets", "full_data_7SMA.csv")
data_dis = read.csv(path) # new_cases is 7 SMA
data_dis = data.table(data_dis) #data_dis will be for discrete case count data

data_dis$date = as.Date(data_dis$date)

# Because we are looking at moving averages, somehow it does not make
# sense to do a poisson regression (on non-integers).
# But there is a quick fix: looking at weekly totals.

data_dis[, new_cases := as.integer(round(new_cases*7))]

# Let us create our "lag" variables
data_dis[, new_cases_f7 := as.integer()] # 7 days in the future (next 7 days block)
data_dis[, new_cases_p2 := as.integer()] # 2 days in the past
data_dis[, new_cases_p4 := as.integer()]
data_dis[, new_cases_p6 := as.integer()]
data_dis[, new_cases_p7 := as.integer()]

for(reg in unique(data_dis$region)){
    data_dis[(date+7) %in% data_dis$date & region == reg,]$new_cases_f7 <-
        data_dis[date %in% (data_dis$date+7) & region == reg,new_cases]

    data_dis[(date-2) %in% data_dis$date & region == reg,]$new_cases_p2 <-
        data_dis[date %in% (data_dis$date-2) & region == reg,new_cases]
    data_dis[(date-4) %in% data_dis$date & region == reg,]$new_cases_p4 <-
        data_dis[date %in% (data_dis$date-4) & region == reg,new_cases]
    data_dis[(date-6) %in% data_dis$date & region == reg,]$new_cases_p6 <-
        data_dis[date %in% (data_dis$date-6) & region == reg,new_cases]
    data_dis[(date-7) %in% data_dis$date & region == reg,]$new_cases_p7 <-
        data_dis[date %in% (data_dis$date-7) & region == reg,new_cases]
}

# PCA Stuff

names(data_dis)
mobility <- names(data_dis)[8:13]

cases <- grep("new_cases", names(data_dis), value=T)

ids <- which(apply(!is.na(data_dis[,..mobility]),1,all))
pca_mobility <- princomp(data_dis[ids,..mobility], cor = T)
plot(pca_mobility)
pca_mobility$loadings

data_dis[ids, pca1 := pca_mobility$scores[,1]]
data_dis[ids, pca2 := pca_mobility$scores[,2]]
##

# Formulas

formula <- new_cases_f7 ~ s(new_cases, k = 7) + s(new_cases_p2, k = 7) + s(new_cases_p4, k = 7) + s(new_cases_p6, k = 7) +
    s(new_cases_p7, k = 7) + population:pca1 + population:pca2 + pop_density + region

id <- which(apply(!is.na(cbind(data_dis[,..mobility],data_dis[,..cases])), 1, all))
data_dis2 <- data_dis[id,]

# =============================== GAM model: Poisson =====================

pois_mod <- gam(formula, data_dis2, family = "poisson")
summary(pois_mod)

# plot smooth effects
plot(pois_mod, residuals = T)

# check diagnostics
gam.check(pois_mod)

AIC(pois_mod)

# =============================== GAM model: Negative Binomial ============

nb_mod <- gam(formula, data_dis2, family = nb(link="sqrt"))
summary(nb_mod)

# plot smooth effects
plot(nb_mod, residuals = T)

# check diagnostics
gam.check(nb_mod)

AIC(nb_mod)

#
#  ==============================  Continuous Case Count Data  =============
#

path = file.path("..", "Datasets", "full_data_7SMA.csv")
data = read.csv(path) # new_cases is 7 SMA
data = data.table(data)

data$date = as.Date(data$date)

# Let us create our "lag" variables
data[, new_cases_f7 := as.double()] # 7 days in the future (next 7 days block)
data[, new_cases_p2 := as.double()] # 2 days in the past
data[, new_cases_p4 := as.double()]
data[, new_cases_p6 := as.double()]
data[, new_cases_p7 := as.double()]

for(reg in unique(data$region)){
    data[(date+7) %in% data$date & region == reg,]$new_cases_f7 <-
        data[date %in% (data$date+7) & region == reg,new_cases]

    data[(date-2) %in% data$date & region == reg,]$new_cases_p2 <-
        data[date %in% (data$date-2) & region == reg,new_cases]
    data[(date-4) %in% data$date & region == reg,]$new_cases_p4 <-
        data[date %in% (data$date-4) & region == reg,new_cases]
    data[(date-6) %in% data$date & region == reg,]$new_cases_p6 <-
        data[date %in% (data$date-6) & region == reg,new_cases]
    data[(date-7) %in% data$date & region == reg,]$new_cases_p7 <-
        data[date %in% (data$date-7) & region == reg,new_cases]
}

# PCA stuff

names(data)
mobility <- names(data)[8:13]

cases <- grep("new_cases", names(data), value=T)

ids <- which(apply(!is.na(data[,..mobility]),1,all))
pca_mobility <- princomp(data[ids,..mobility], cor = T)
plot(pca_mobility)
pca_mobility$loadings

data[ids, pca1 := pca_mobility$scores[,1]]
data[ids, pca2 := pca_mobility$scores[,2]]

# Formulas

formula <- new_cases_f7 ~ s(new_cases, k = 7) + s(new_cases_p2, k = 7) + s(new_cases_p4, k = 7) + s(new_cases_p6, k = 7) +
    s(new_cases_p7, k = 7) + population:pca1 + population:pca2 + pop_density + region

id <- which(apply(!is.na(cbind(data[,..mobility],data[,..cases])), 1, all))
data2 <- data[id,]

#  ==============================  GAM model: Gaussian  ========================

g_mod <- gam(formula, data = data2, family = gaussian)
summary(g_mod)

# plot smooth effects
plot(g_mod, residuals = T)

# check diagnostics
gam.check(g_mod)

AIC(g_mod)

#  ==============================  GAM model: Scaled t  ========================

t_mod <- gam(formula, data = data2, family = scat)
summary(t_mod)

# plot smooth effects
plot(t_mod, residuals = T)

# check diagnostics
gam.check(t_mod)

AIC(t_mod)
