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

# ----- import base data - kaggle's PG data set -----
pg01 <- as_tibble(read_csv("C:/Users/Personal Computer/Documents/git_repo/William-Au-Portfolio/unsupervised_pokemon_go/pokemonGO.csv", 
        col_names = TRUE)) %>%
    dplyr::select(-`Image URL`) %>%
    rename(pm_nbr = `Pokemon No.`, typ1 = `Type 1`, typ2 = `Type 2`, 
        max_cp = `Max CP`, max_hp = `Max HP`, name = Name) %>%
    arrange(pm_nbr)
glimpse(pg01)  # not all pokemon have secondary type
summary(pg01)  # no missing values except for secondary type


# ----- import base data - Game Press' IV spreadsheet -----
pg02 <- as_tibble(read_csv(
        "C:/Users/Personal Computer/Documents/git_repo/William-Au-Portfolio/unsupervised_pokemon_go/TDO SHEET BY DPS - Sheet1.csv", 
        col_names = TRUE)) %>%
    mutate(pm_nbr = ifelse(dex >= 100, as.character(dex),
        ifelse(dex >= 10, str_c("0", as.character(dex)),
            str_c("00", as.character(dex))))) %>%
    select(pm_nbr, pokemon, WeaveDPS, TDO, `~TDO per CP`, `~SurvivalTime`) %>%
    rename(weave_dps = WeaveDPS, tdo = TDO, tdo_cp = `~TDO per CP`, 
        surv_time = `~SurvivalTime`) %>%
    arrange(pm_nbr, desc(tdo)) %>%
    group_by(pm_nbr) %>%
    filter(tdo == max(tdo)) %>%
    filter(weave_dps == max(weave_dps)) %>%
    ungroup() %>%
    distinct(pm_nbr, pokemon, weave_dps, tdo, tdo_cp, surv_time)
glimpse(pg02)
summary(pg02)

# ----- transform by encoding dummy variables -----
dmy <- dummyVars("~ typ1 + typ2", data = pg01)
pg03 <- as_tibble(predict(dmy, newdata = pg01)) %>%
    replace(., is.na(.), 0) %>%
    mutate(
        typ_bug = as.factor(typ1Bug),
        typ_dragon = as.factor(typ1Dragon),
        typ_electric = as.factor(typ1Electric),
        typ_fairy = as.factor(pmax(typ1Fairy, typ2Fairy)),
        typ_fighting = as.factor(pmax(typ1Fighting, typ2Fighting)),
        typ_fire = as.factor(typ1Fire),
        typ_ghost = as.factor(typ1Ghost),
        typ_grass = as.factor(pmax(typ1Grass, typ2Grass)),
        typ_ground = as.factor(pmax(typ1Ground, typ2Ground)),
        typ_ice = as.factor(pmax(typ1Ice, typ2Ice)),
        typ_normal = as.factor(typ1Normal),
        typ_poison = as.factor(pmax(typ1Poison, typ2Poison)),
        typ_psychic = as.factor(pmax(typ1Psychic, typ2Psychic)),
        typ_rock = as.factor(pmax(typ1Rock, typ2Rock)),
        typ_water = as.factor(pmax(typ1Water, typ2Water)),
        typ_flying = as.factor(typ2Flying),
        typ_steel = as.factor(typ2Steel)) %>%
    bind_cols(pg01) %>%
    select(max_cp, max_hp, starts_with("typ_"))
summary(pg03)
glimpse(pg03)

# ----- wrangle to combine data sets -----
pg04 <- pg01 %>%
    left_join(pg02, by = "pm_nbr") %>%
    select(pm_nbr, name, typ1, typ2, weave_dps, tdo, tdo_cp, surv_time) %>%
    bind_cols(pg03) %>%
    filter(weave_dps >= 0)  # few small species missing

# ----- explore KPI distributions -----
ggplot(data = pg04, aes(max_cp)) + geom_density(kernel = "gaussian", 
    fill = "red") + theme_minimal()
ggplot(data = pg04, aes(max_hp)) + geom_density(kernel = "gaussian", 
    fill = "red") + theme_minimal()
ggplot(data = pg04, aes(weave_dps)) + geom_density(kernel = "gaussian", 
    fill = "red") + theme_minimal()
ggplot(data = pg04, aes(tdo)) + geom_density(kernel = "gaussian", 
    fill = "red") + theme_minimal()
ggplot(data = pg04, aes(tdo_cp)) + geom_density(kernel = "gaussian", 
    fill = "red") + theme_minimal()
ggplot(data = pg04, aes(surv_time)) + geom_density(kernel = "gaussian", 
    fill = "red") + theme_minimal()

# ----- explore KPI distributions by first type -----
ggplot(data = pg04, aes(x = typ1, y = max_cp)) + 
    geom_violin(trim = FALSE, fill = "green") + 
    stat_summary(fun.data = mean_sdl, geom = "pointrange", color = "red") + 
    theme_minimal()
ggplot(data = pg04, aes(x = typ1, y = max_hp)) + 
    geom_violin(trim = FALSE, fill = "green") + 
    stat_summary(fun.data = mean_sdl, geom = "pointrange", color = "red") + 
    theme_minimal()
ggplot(data = pg04, aes(x = typ1, y = weave_dps)) + 
    geom_violin(trim = FALSE, fill = "green") + 
    stat_summary(fun.data = mean_sdl, geom = "pointrange", color = "red") + 
    theme_minimal()
ggplot(data = pg04, aes(x = typ1, y = tdo)) + 
    geom_violin(trim = FALSE, fill = "green") + 
    stat_summary(fun.data = mean_sdl, geom = "pointrange", color = "red") + 
    theme_minimal()
ggplot(data = pg04, aes(x = typ1, y = tdo_cp)) + 
    geom_violin(trim = FALSE, fill = "green") + 
    stat_summary(fun.data = mean_sdl, geom = "pointrange", color = "red") + 
    theme_minimal()
ggplot(data = pg04, aes(x = typ1, y = surv_time)) + 
    geom_violin(trim = FALSE, fill = "green") + 
    stat_summary(fun.data = mean_sdl, geom = "pointrange", color = "red") + 
    theme_minimal()

# ----- explore KPI distributions by second type (if available) -----
ggplot(data = pg04, aes(x = typ2, y = max_cp)) + 
    geom_violin(trim = FALSE, fill = "green") + 
    stat_summary(fun.data = mean_sdl, geom = "pointrange", color = "red") + 
    theme_minimal()
ggplot(data = pg04, aes(x = typ2, y = max_hp)) + 
    geom_violin(trim = FALSE, fill = "green") + 
    stat_summary(fun.data = mean_sdl, geom = "pointrange", color = "red") + 
    theme_minimal()
ggplot(data = pg04, aes(x = typ2, y = weave_dps)) + 
    geom_violin(trim = FALSE, fill = "green") + 
    stat_summary(fun.data = mean_sdl, geom = "pointrange", color = "red") + 
    theme_minimal()
ggplot(data = pg04, aes(x = typ2, y = tdo)) + 
    geom_violin(trim = FALSE, fill = "green") + 
    stat_summary(fun.data = mean_sdl, geom = "pointrange", color = "red") + 
    theme_minimal()
ggplot(data = pg04, aes(x = typ2, y = tdo_cp)) + 
    geom_violin(trim = FALSE, fill = "green") + 
    stat_summary(fun.data = mean_sdl, geom = "pointrange", color = "red") + 
    theme_minimal()
ggplot(data = pg04, aes(x = typ2, y = surv_time)) + 
    geom_violin(trim = FALSE, fill = "green") + 
    stat_summary(fun.data = mean_sdl, geom = "pointrange", color = "red") + 
    theme_minimal()

# ----- explore two-way KPI distributions and correlations -----
ggpairs(pg04, columns = 5:10, aes(alpha = 0.1), upper = list("cor")) + 
    theme_minimal()  # drop dps, tdo, tdo_cp b/c of high corr


# ----- select variables for clustering -----
pg05 <- as.data.frame(pg04) %>%
    select(starts_with("typ_"), max_cp, max_hp, surv_time)
# as the correlation plot showed, dps, tdo, tdo_cp was dropped due to high corr
# daisy function doesn't like tibbles

# ----- transform by calculating Gower distances with mixed data types -----
pg06_dist <- daisy(pg05, metric = "gower", type = list(
    asymm = 
        c("typ_bug", "typ_dragon", "typ_electric", "typ_fairy", "typ_fighting",
            "typ_fire", "typ_ghost", "typ_grass", "typ_ground", "typ_ice",
            "typ_normal", "typ_poison", "typ_psychic", "typ_rock", "typ_water",
            "typ_flying", "typ_steel"),
    logratio = c("max_cp", "max_hp", "surv_time")))
summary(pg06_dist)

# ----- tune hyperparameters for dbscan clustering -----
dbscan::kNNdistplot(pg06_dist, k = 1)
abline(h = 0.09, lty = 2)  
dbscan::kNNdistplot(pg06_dist, k = 1)
abline(h = 0.24, lty = 2)  
dbscan::kNNdistplot(pg06_dist, k = 2)
abline(h = 0.27, lty = 2)  
dbscan::kNNdistplot(pg06_dist, k = 2)
abline(h = 0.36, lty = 2)  

# ----- conduct dbscan clustering -----
pg07_dbs <- fpc::dbscan(pg06_dist, eps = 0.24, MinPts = 1)
fviz_cluster(pg07_dbs, data = pg06_dist, stand = TRUE, ellipse = TRUE, 
    show.clust.cent = TRUE, palette = "paired", geom = "point", pointsize = 1,
    repel = TRUE, ggtheme = theme_minimal()) + coord_fixed()

# ----- tabulate member results -----
pg08_clus <- as_tibble(pg07_dbs$cluster) %>%
    bind_cols(pg04) %>%
    rename(cluster = value)
table(pg08_clus$cluster)

# ----- investigate parabolic cluster pattern in upper right of scatter -----
tmp <- pg08_clus %>%
    select(cluster, name) %>%
    filter(cluster %in% c(43, 9, 8, 7)) %>%
    mutate(order = ifelse(cluster == 43, 1,
        ifelse(cluster == 9, 2, 
            ifelse(cluster == 8, 3, 4)))) %>%
    arrange(order, name)
