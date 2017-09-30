#!/usr/bin/Rscript

args = commandArgs(trailingOnly=TRUE)
n <- max(1, floor(sqrt(length(args))))
m <- ceiling(length(args) / n)
print(m)
print(n)
print(length(args))
pdf(width=20, height=20)
par(mfrow=c(n, m))
for (file in args) {
	data <- read.table(file)
	plot(data)
	title(file)
}
