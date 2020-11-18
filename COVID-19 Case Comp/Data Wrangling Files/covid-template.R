library(data.table)
library(mgcv)
library(dplyr)
library(knitr)
library(pivottabler)
library(ggplot2)

# Setup data --------------------------------------------------------------


can_data_path <- "../Datasets/data_can2.csv"

# Read
data_can <- fread(can_data_path)

# Identify responses
names(data_can)
responses <- names(data_can)[5:11]
responses

# 3 columns empty
data_can[, ..responses]
all(is.na(data_can$hosp))
all(is.na(data_can$vent))
all(is.na(data_can$icu))

# remove them
responses <- responses[1:4]

# For convenience
names(data_can)[names(data_can) == "administrative_area_level_1"] <- "country"
names(data_can)[names(data_can) == "administrative_area_level_2"] <- "province"

# create new variables for "number of new.."
for(prov in data_can[,unique(province)]){
  data_can[province == prov, (paste0("new_", responses)) := lapply(.SD, function(v) c(0,diff(v))),
           .SDcols = responses]
}




# GAM model for a single province -----------------------------------------

# Let us focus on Ontario first...
data_ont <- data_can[province == "Ontario"]

ggplot(data_ont, aes(x = date, y = new_confirmed)) +
  geom_line() +
  theme_light()

# What I suggest is first taking care of the overall
# shape using a nonlinear effect on time
data_ont[,time := as.numeric(date)]
head(data_ont[,date])
head(data_ont[,time])

# first a spline with 3 knots (not so good, or is it?)
formula <- new_confirmed ~ s(time, k=4)
mod_ont <- gam(formula, data_ont, family = "poisson")

data_ont[, pred1_nc := mod_ont$fitted.values]
ggplot(data_ont, aes(x = date)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred1_nc), col="red") +
  theme_light()

# let us take 7 (just cause it looks good)
formula <- new_confirmed ~ s(time, k=7)
mod_ont <- gam(formula, data_ont, family = "poisson")

data_ont[, pred2_nc := mod_ont$fitted.values]
ggplot(data_ont, aes(x = date)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred1_nc), col="red") +
  geom_line(aes(y = pred2_nc), col="blue") +
  theme_light()

# Our objective is now to explain the residuals of this
# model with mobility variables, from a couple days ago
# (Or should we try to explain the slope?)

# As an example
rpc0 <- data_ont$residential_percent_change_from_baseline
n_ont <- nrow(data_ont)
for(i in 3:7){
  data_ont[, paste0("rpc",i) := c(rep(NA,i),rpc0[1:(n_ont-i)])]
}

# with k=4
formula <- new_confirmed ~ s(time, k=4) +
  rpc3 + rpc4 + rpc5 + rpc6 + rpc7
mod_ont <- gam(formula, data_ont, family = "poisson")

# I use sapply to manage the NAs..
data_ont[, pred3_nc := sapply(1:nrow(data_ont), function(i) predict(mod_ont, data_ont[i,], type="response"))]

# with k=7
formula <- new_confirmed ~ s(time, k=7) +
  rpc3 + rpc4 + rpc5 + rpc6 + rpc7
mod_ont <- gam(formula, data_ont, family = "poisson")
data_ont[, pred4_nc := sapply(1:nrow(data_ont), function(i) predict(mod_ont, data_ont[i,], type="response"))]

ggplot(data_ont, aes(x = date)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred1_nc), col="red") +
  geom_line(aes(y = pred2_nc), col="blue") +
  geom_line(aes(y = pred3_nc), col="orange") +
  geom_line(aes(y = pred4_nc), col="green") +
  theme_light()


# Let's put even more degrees of freedom on the spline...
formula <- new_confirmed ~ s(time, k=10)
mod_ont <- gam(formula, data_ont, family = "poisson")
data_ont[, pred5_nc := sapply(1:nrow(data_ont), function(i) predict(mod_ont, data_ont[i,], type="response"))]

formula <- new_confirmed ~ s(time, k=10) +
  rpc3 + rpc4 + rpc5 + rpc6 + rpc7
mod_ont <- gam(formula, data_ont, family = "poisson")
data_ont[, pred6_nc := sapply(1:nrow(data_ont), function(i) predict(mod_ont, data_ont[i,], type="response"))]

ggplot(data_ont, aes(x = date)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred5_nc), col="red") +
  geom_line(aes(y = pred6_nc), col="blue") +
  theme_light()





# GAM model for multiple provinces ----------------------------------------

# For viz, we'll focus on
provs <- c("Ontario", "Quebec", "British Columbia")
data_can <- data_can[province %in% provs,]

# same new time variables
data_can[,time := as.numeric(date)]

# We now want something like
formula <- new_confirmed ~ log(population) + s(time, k=7)
mod_can <- gam(formula, data_can, family = "poisson")

data_can[, pred1_nc := mod_can$fitted.values]
ggplot(data_can, aes(x = date, col=province)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred1_nc)) +
  theme_light() +
  theme(legend.position = "none") +
  facet_wrap(~province, scales="free")

# This does not do the trick... for obvious reasons...
# Let's check this (a little longer to run)
formula <- new_confirmed ~ log(population) +
  s(time, k = 8, by = interaction(province))
mod_can <- gam(formula, data_can, family = "poisson")

data_can[, pred2_nc := mod_can$fitted.values]
ggplot(data_can, aes(x = date, col=province)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred1_nc), col = "lightgray") +
  geom_line(aes(y = pred2_nc)) +
  theme_light() +
  theme(legend.position = "none") +
  facet_wrap(~province, scales="free")

# Much better. Now, let us introduce the mobility variables
for(prov in data_can[,unique(province)]){
  n_prov <- nrow(data_can[province == prov])
  rpc0 <- data_can[province == prov,]$residential_percent_change_from_baseline
  for(i in 3:7){
    data_can[province == prov, paste0("rpc",i) := c(rep(NA,i),rpc0[1:(n_prov-i)])]
  }
}

formula <- new_confirmed ~ log(population) +
  rpc3 + rpc4 + rpc5 + rpc6 + rpc7 +
  s(time, k = 8, by = interaction(province))
mod_can <- gam(formula, data_can, family = "poisson")

data_can[, pred3_nc := sapply(1:nrow(data_can), function(i) predict(mod_can, data_can[i,], type="response"))]
ggplot(data_can, aes(x = date, col=province)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred1_nc), col = "lightgray") +
  geom_line(aes(y = pred2_nc), col = "lightgray") +
  geom_line(aes(y = pred3_nc)) +
  theme_light() +
  theme(legend.position = "none") +
  facet_wrap(~province, scales="free")


# A lot of interesting things can be done..
data_can[, dow := weekdays(date)]
formula <- new_confirmed ~ log(population) +
  dow*province +
  rpc3 + rpc4 + rpc5 + rpc6 + rpc7 +
  s(time, by = interaction(province))
mod_can <- gam(formula, data_can, family = "poisson")

data_can[, pred4_nc := sapply(1:nrow(data_can), function(i) predict(mod_can, data_can[i,], type="response"))]
ggplot(data_can, aes(x = date, col=province)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred4_nc)) +
  theme_light() +
  theme(legend.position = "none") +
  facet_wrap(~province, scales="free")






# ...
for(prov in data_can[,unique(province)]){
  
  rpc0 <- frollmean(data_can[province==prov]$residential_percent_change_from_baseline, 5)
  wpc0 <- frollmean(data_can[province==prov]$workplaces_percent_change_from_baseline, 5)
  
  data_can[province == prov, "rpc5" := c(rep(NA,5),rpc0[1:(n_prov-5)])]
  data_can[province == prov, "wpc5" := c(rep(NA,5),wpc0[1:(n_prov-5)])]
}

formula <- new_confirmed ~ log(population) +
  dow*province +
  s(rpc5) + s(wpc5) +
  s(time, k=3, by = interaction(province))
mod_can <- gam(formula, data_can, family = "poisson")

data_can[, pred5_nc := sapply(1:nrow(data_can), function(i) predict(mod_can, data_can[i,], type="response"))]
ggplot(data_can, aes(x = date, col=province)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred5_nc)) +
  theme_light() +
  theme(legend.position = "none") +
  facet_wrap(~province, scales="free")

par(mfrow=c(1,1))
plot(mod_can)



formula <- new_confirmed ~ log(population) +
  dow*province +
  s(rpc5, k=2) + s(wpc5, k=2)
mod_can <- gam(formula, data_can, family = "poisson")

data_can[, pred5_nc := sapply(1:nrow(data_can), function(i) predict(mod_can, data_can[i,], type="response"))]
ggplot(data_can, aes(x = date, col=province)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred5_nc)) +
  theme_light() +
  theme(legend.position = "none") +
  facet_wrap(~province, scales="free")

par(mfrow=c(1,1))
plot(mod_can)
