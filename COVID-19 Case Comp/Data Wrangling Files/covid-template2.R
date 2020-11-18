library(data.table)
library(mgcv)




# Setup data --------------------------------------------------------------

# Read
data_can <- fread("YOURPATH.csv")

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

data_ont[, pred1_nc := predict(mod_ont,type="response")]
ggplot(data_ont, aes(x = date)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred1_nc), col="red") +
  theme_light()

# let us take 7 (just cause it looks good)
formula <- new_confirmed ~ s(time, k=7)
mod_ont <- gam(formula, data_ont, family = "poisson")

data_ont[, pred2_nc := predict(mod_ont,type="response")]
ggplot(data_ont, aes(x = date)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred1_nc), col="red") +
  geom_line(aes(y = pred2_nc), col="blue") +
  theme_light()

# Our objective is now to model the residuals of this
# model with mobility variables (from a couple days ago)

rpc0 <- data_ont$residential_percent_change_from_baseline
for(i in 3:5){
  data_ont[, paste0("rpc",i) := c(rpc0[-(1:i)],rep(NA,i))]
}

# with k=4
formula <- new_confirmed ~ s(time, k=4) +
  rpc3 + rpc4 + rpc5
mod_ont <- gam(formula, data_ont, family = "poisson")
pred3 <- predict(mod_ont,type="response")
data_ont[which(!is.na(rpc5)), pred3_nc := pred3]

# with k=7
formula <- new_confirmed ~ s(time, k=7) +
  rpc3 + rpc4 + rpc5
mod_ont <- gam(formula, data_ont, family = "poisson")
pred4 <- predict(mod_ont,type="response")
data_ont[which(!is.na(rpc5)), pred4_nc := pred4]

ggplot(data_ont, aes(x = date)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred1_nc), col="red") +
  geom_line(aes(y = pred2_nc), col="blue") +
  geom_line(aes(y = pred3_nc), col="orange") +
  geom_line(aes(y = pred4_nc), col="green") +
  theme_light()

# It seems that all the signal from the rcps is 
# already accounted for in s(time, k=7)...
# But is the model with k=4 really better?
# I would integrate the other variables and see what 
# happens...




# GAM model for multiple provinces ----------------------------------------

# For viz, we'll focus on
provs <- c("Ontario", "Quebec", "British Columbia")

# clear negative values.. data should be cleaned
data_can[new_confirmed < 0, new_confirmed := NA]

# same new time variables
data_can[,time := as.numeric(date)]

# We now want something like
formula <- new_confirmed ~ log(population) + s(time, k=7)
mod_can <- gam(formula, data_can, family = "poisson")

data_can[which(!is.na(new_confirmed)), pred1_nc := mod_can$fitted.values]
ggplot(data_can[province %in% provs], aes(x = date, col=province)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred1_nc)) +
  theme_light() +
  facet_wrap(~province, scales="free")

# This does not do the trick... for obvious reasons...
# Let's check this (a little long to run)
formula <- new_confirmed ~ log(population) +
  s(time, by = interaction(province))
mod_can <- gam(formula, data_can, family = "poisson")

data_can[which(!is.na(new_confirmed)), pred2_nc := mod_can$fitted.values]
ggplot(data_can[province %in% provs], aes(x = date, col=province)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred1_nc), col = "lightgray") +
  geom_line(aes(y = pred2_nc)) +
  theme_light() +
  theme(legend.position = "none") +
  facet_wrap(~province, scales="free")

# Much better. Now, let us introduce the mobility variables
for(prov in data_can[,unique(province)]){
  rpc0 <- data_can[province == prov,]$residential_percent_change_from_baseline
  for(i in 3:5){
    data_can[province == prov, paste0("rpc",i) := c(rpc0[-(1:i)],rep(NA,i))]
  }
}

formula <- new_confirmed ~ log(population) + s(time, k=7)
mod_can <- gam(formula, data_can, family = "poisson")

length(predict(mod_can, type = "response"))

# very ugly sorry..
keep <- which(
  apply(
    !is.na(data_can[,cbind(new_confirmed,rpc3,rpc4,rpc5)]),
    1,
    all))

data_can[keep, pred3_nc := mod_can$fitted.values]
ggplot(data_can[province %in% provs], aes(x = date, col=province)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred1_nc), col = "lightgray") +
  geom_line(aes(y = pred2_nc), col = "lightgray") +
  geom_line(aes(y = pred3_nc)) +
  theme_light() +
  theme(legend.position = "none") +
  facet_wrap(~province, scales="free")

formula <- new_confirmed ~ log(population) +
  rpc3 + rpc4 + rpc5 +
  s(time, by = interaction(province))
mod_can <- gam(formula, data_can, family = "poisson")

data_can[which(!is.na(new_confirmed)), pred3_nc := mod_can$fitted.values]
ggplot(data_can[province %in% provs], aes(x = date, col=province)) +
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
  rpc3 + rpc4 + rpc5 +
  s(time, by = interaction(province))
mod_can <- gam(formula, data_can, family = "poisson")

data_can[keep, pred4_nc := mod_can$fitted.values]
ggplot(data_can[province %in% provs], aes(x = date, col=province)) +
  geom_line(aes(y = new_confirmed), col="black") +
  geom_line(aes(y = pred4_nc)) +
  theme_light() +
  theme(legend.position = "none") +
  facet_wrap(~province, scales="free")