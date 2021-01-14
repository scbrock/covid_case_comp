# Principal components of mobility ----------------------------------------

ids <- which(apply(!is.na(data[,..mobility]),1,all))
pca_mobility <- princomp(data[ids,..mobility], cor = T)
plot(pca_mobility)
print(pca_mobility)

pca_mobility$loadings
pca_mobility$scores[1,1]

obs1 <- unlist(data[ids,][1,..mobility])
obs1 <- (obs1 - pca_mobility$center)/pca_mobility$scale
t(obs1) %*% pca_mobility$loadings 
# It seems reasonable to keep only two components,
# but let us keep 4 for the moment
data[ids, pca1 := pca_mobility$scores[,1]]
data[ids, pca2 := pca_mobility$scores[,2]]
data[ids, pca3 := pca_mobility$scores[,3]]
data[ids, pca4 := pca_mobility$scores[,4]]

# Let us visualize what they are.
# Note that they are "artificially inflated" so that we
# have similar scales for the different objects in the plots
gg <- ggplot() +
  geom_line(data=data_mobility, aes(x=date, y=mobility_value, col=mobility_type)) +
  facet_wrap(~region)

gg  
gg + geom_line(data=data, aes(x=date, y=pca1*10), lty=2)
gg + geom_line(data=data, aes(x=date, y=pca2*90), lty=2)
gg + geom_line(data=data, aes(x=date, y=pca3*90), lty=2)
gg + geom_line(data=data, aes(x=date, y=pca4*90), lty=2)

