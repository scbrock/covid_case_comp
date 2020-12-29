# Change working directory
cwd = getwd()
wd = file.path(cwd, "COVID-19 Case Comp", "R files")
setwd(wd)

library(mgcv)
library(ggplot2)
library(data.table)
library(dplyr)

path = file.path("..", "Datasets", "Mobility Data", "2020_US_Region_Mobility_Report.csv")
mob_data = read.csv(path)

colnames(mob_data)[6] = "state"
mob_data = filter(mob_data, state != "")
mob_data$state = sapply(mob_data$state, function(x) {gsub("US-", "", x)})
mob_data$state = as.factor(mob_data$state)
mob_data$date = as.Date(mob_data$date, format = "%Y-%m-%d")

path = file.path("usdata.csv")
usdata = read.csv(path, stringsAsFactors = FALSE)
usdata = usdata[, c(2, 3, 7, 12, ncol(usdata))]
colnames(usdata)[1] = "date"
usdata[1, ]
str(usdata$date)
usdata$date = strptime(usdata$date,format="%m/%d/%Y")
usdata$date = as.Date(usdata$date, format = "%Y-%m-%d")

# now merge mob_data and usdata. Merge on state
usd = merge(mob_data, usdata)
#write.csv(usd, file="usdata.csv")


mob_data = mob_data[, c(6, 8, 9, 10, 11, 12, 13, 14)]
colnames(mob_data)
state_pops = list(
    "CO" = 5758736,
    "FL" = 21477737,
    "AZ" = 7278717,
    "SC" = 5148714,
    "CT" = 3565287,
    "NE" = 1934408,
    "KY" = 4467673,
    "WY" = 578759,
    "IA" = 3155070,
    "NM" = 2096829,
    "ND" = 762062,
    "WA" = 7614893,
    "RMI" = 51433,
    "TN" = 6829174,
    "AS" = 49437, # american samoa
    "MA" = 6892503,
    "PA" = 12801989,
    "NYC" = NA,
    "OH" = 11689100,
    "VA" = 8535519,
    "MI" = 9986857,
    "AL" = 4903185,
    "GA" = 10617423,
    "MS" = 2976149,
    "WI" = 5822434,
    "IL" = 12671821,
    "PR" = 3193694,
    "TX" = 28995881,
    "ID" = 1787065,
    "LA" = 4648794,
    "OK" = 3956971,
    "CA" = 39512223,
    "NJ" = 8882190,
    "IN" = 6732219,
    "NV" = 3080156,
    "AR" = 3017804,
    "MN" = 5639632,
    "MD" = 6045680,
    "NY" = 19453561,
    "OR" = 4217737,
    "UT" = 3205958,
    "WV" = 1792147,
    "MO" = 6137428,
    "DE" = 973764,
    "SD" = 884659,
    "RI" = 1059361,
    "KS" = 2913314,
    "NH" = 1359711,
    "ME" = 1344212,
    "MT" = 1068778,
    "NC" = 10488084,
    "DC" = 705749,
    "AK" = 731545,
    "HI" = 1415872,
    "GU" = NA,
    "VT" = 623989,
    "VI" = 106235,
    "MP" = NA,
    "FSM" = NA,
    "PW" = NA
)
population = rep(0, nrow(usdata))
i = 1
for (state in usdata$state) {
    population[i] = state_pops[[state]]
    i = i + 1
}
usdata$population = population
colnames(usdata)
#write.csv(usdata, file="usdata.csv")

# get data
path = file.path("..", "Datasets", "ontario_region_model_data",
"ontario_region_model_data.csv")
ont_data = read.csv(path)
ont_data = data.table(ont_data)
ont_data = ont_data[-c(1, 2)] # Drop index column and intercept column

# create new lag variables:
# new_casesi: new_cases on ith preceding day
n_ont <- nrow(ont_data)
for(i in 1:6){
    ont_data[, paste0("new_cases",i) := c(rep(NA,i),new_cases[1:(n_ont-i)])]
}
colnames(ont_data)
head(ont_data)
ont_data = na.omit(ont_data) # remove NAs
ont_data = data.table(ont_data)
formula = new_lag7 ~ new_cases + pop_density + transit + parks + retail.rec +
        workplaces + is_spring + is_summer + grocery.pharm + residential +
        new_cases1 + new_cases2 + new_cases3 + new_cases4 + new_cases5 +
        new_cases6 + is_fall + is_weekday + s(region, bs = 're') +
        s(day_num, k=7)
ont_model = gam(formula = formula,
    family='poisson',
    offset = log(population),
    data = ont_data)

ont_data[, pred1_nc := ont_model$fitted.values]
ggplot(ont_data, aes(x = date)) +
    geom_line(aes(y = new7), col="black") +
    geom_line(aes(y = pred1_nc), col="red") +
    theme_light()
summary(ont_model)
