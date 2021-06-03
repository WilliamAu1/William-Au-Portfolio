Detecting Species Redundancy in Pokemon GO - Gotta Catch (Most of) ’Em
All
================
William Au
October 11, 2018

## Introduction

Pokemon GO is a mobile, location-based game where players can catch
Pokemon for purposes of battling gyms, raiding gyms, defending gyms,
trading or simply collecting. There are constraints such that a player
cannot own all combinations of Pokemon in a play-able state (i.e., in
their Pokemon box):

``` r
# ----- admin -----
rm(list = ls())  # clear environment
library(rmarkdown)  # markdown
library(knitr)  # knitr
library(tidyverse)  # for tidy data import and wrangling
library(factoextra)  # for cluster visualization
library(fpc)  # for dbscan clustering
library(caret)  # for dummy variables
library(cluster)  # for clustering
library(GGally)  # for matrix plotting
library(RColorBrewer)  # for color palettes
gc()  # garbage collection
set.seed(888)  # set seed for random number generation reproducibility


# import 2019 data
s01 <- as_tibble(read_csv("tbs-pssd-compendium-2019-en-2020-12-21.csv", 
        col_names = TRUE))
glimpse(s01)
```