# admin -------------------------------------------------------------------
# ctrl-shift R
rm(list = ls())
library(tidyverse)


# import ------------------------------------------------------------------
# import data, filter to include only FSA-lvl & STR's
f1 <- as_tibble(read_csv(
    "Change Detection in FINTRAC Reporting/fintrac-canafe_data-donnees.csv", col_names = FALSE, skip = 1)) %>%
    rename(activity_sector = X1, pc = X2, rep_typ = X3, rep_yr_mth = X4,
        rep_num = X5) %>%
    filter(
        str_length(pc) == 3,
        str_detect(rep_typ, "STR") == TRUE) %>%
    mutate(rep_dt = 
            lubridate::as_date(str_c(
                str_sub(as.character(rep_yr_mth), 1, 4), 
                "/",
                str_sub(as.character(rep_yr_mth), 5, 6), 
                "/",
                "01")),
        sector = 
            ifelse(str_detect(activity_sector, "Banks") > 0, "BANK",
            ifelse(str_detect(activity_sector, "Accountant") > 0, "ACCOUNTANT",
            ifelse(str_detect(activity_sector, "Credit") > 0, "CREDIT UNION",
            ifelse(str_detect(activity_sector, "precious") > 0, "PRECIOUS",
            ifelse(str_detect(activity_sector, "Life") > 0, "LIFE INS",
            ifelse(str_detect(activity_sector, "Money") > 0, "MONEY SERV",
            ifelse(str_detect(activity_sector, "Real") > 0, "REAL EST",
            ifelse(str_detect(activity_sector, "Securities") > 0, "SECURITIES",
            ifelse(str_detect(activity_sector, "Trust") > 0, "TRUST", 
            "UK")))))))))
        ) %>%
    select(-c(X6, rep_typ, rep_yr_mth, activity_sector))
# EDA ---------------------------------------------------------------------
tmp_eda <- f1 %>%
    group_by(rep_dt) %>%
    summarise(rep_num = sum(rep_num)) %>%
    ungroup()
ggplot(tmp_eda, aes(x = rep_dt, y = rep_num)) + geom_line() + theme_minimal() + 
    labs(title = "Total monthly suspicious transaction reports") + 
    scale_y_continuous(labels = comma) + xlab("") + ylab("")

tmp_eda <- f1 %>%
    group_by(rep_dt, sector) %>%
    summarise(rep_num = sum(rep_num)) %>%
    ungroup()
ggplot(tmp_eda, aes(x = rep_dt, y = rep_num)) + geom_line() + 
    facet_wrap(vars(sector), ncol = 1, scales = "free") + 
    theme_void() + 
    labs(title = "Total STRs over time by activity sector")

tmp_eda$sector <- factor(tmp_eda$sector , 
    levels = c("BANK", "MONEY SERV", "CREDIT UNION", "TRUST", "SECURITIES", 
    "LIFE INS", "PRECIOUS", "REAL EST"))
ggplot(tmp_eda, aes(x = rep_dt, y = rep_num, fill = sector)) + 
    geom_area(alpha = 0.6 , size = 1) + theme_void() +
    labs(title = "Total STRs over time by activity sector (stacked view)")

tmp_eda <- f1  %>%
    group_by(rep_dt, sector) %>%
    summarise(n = sum(rep_num)) %>%
    mutate(percentage = n / sum(n)) %>%
    ungroup()
tmp_eda$sector <- factor(tmp_eda$sector , 
    levels = c("BANK", "MONEY SERV", "CREDIT UNION", "TRUST", "SECURITIES", 
    "LIFE INS", "PRECIOUS", "REAL EST"))
ggplot(tmp_eda, aes(x = rep_dt, y = percentage, fill = sector)) + 
    geom_area(alpha = 0.6 , size = 0.1, colour = "black") + theme_void() +
    labs(title = "Total STRs over time by activity sector (stacked % view)")
rm(tmp_eda)
# lots more STR in recent times in aggregate (2018+)
# banks and credit unions up, money services kind of up, precious down, 
    # real estate spike, securities flat, trust up
# magnitude in order of factor levels
# banks became way bigger % over time and money services way less





# FSA-level model ---------------------------------------------------------
# aggregate FSA-lvl CUSUM with T and C hyperparam grid search
tmp_mu <- f1 %>%    
    group_by(pc) %>%
    summarise(mu = mean(rep_num)) %>%
    ungroup()
# 235 is max mu, 36922 is max st when C==0, >9 trillion combinations of C-T-FSA
# ggplot(tmp_mu, aes(x = mu)) + geom_histogram() + theme_minimal()
# ggplot(f2_fsa, aes(x = st)) + geom_histogram() + theme_minimal()
cusum_fsa <- function(C, T) {
    tmp_fsa <- f1 %>%
        group_by(pc, rep_dt) %>%
        summarise(rep_num = sum(rep_num)) %>%
        ungroup() %>%
        arrange(pc, rep_dt) %>%
        left_join(tmp_mu, by = "pc") %>%
        group_by(pc) %>%
        mutate(
            xt = ifelse(is.na(lag(rep_num, n = 1)), rep_num, 
                lag(rep_num, n = 1)),
            cum_sum = cumsum(xt),
            tmp = ifelse(is.na(
                lag(cum_sum, n = 1) + (xt - mu - C)), mu,
                lag(cum_sum, n = 1) + (xt - mu - C))) %>%
        ungroup() %>%
        rowwise() %>%
        mutate(
            st = max(0, tmp),
            chg_ind = ifelse(st >= T, "Y", "N")) %>%
        ungroup() %>%
        arrange(pc, rep_dt) %>%
        group_by(pc) %>%
        filter(row_number() >= (n() - 1)) %>%
        ungroup() %>%
        group_by(pc) %>%
        filter(chg_ind == "Y" & lag(chg_ind, n = 1) == "N") %>%
        ungroup() %>%
        select(pc, chg_ind)
    invisible(as_tibble(tmp_fsa))
}
hyperparams = list(
    C = seq(0, 240, by = 20),
    T = seq(0, 37000, by = 1000))
f2_fsa <- cusum_fsa(C = 5000, T = 40000)  # create empty tibble to row_bind
for (i in hyperparams$C) {
    for (j in hyperparams$T) {
        tmp <- cusum_fsa(C = i, T = j)
        f2_fsa <- f2_fsa %>% 
            bind_rows(tmp)}}
f3_fsa <- f2_fsa %>%
    group_by(pc) %>%
    count() %>%
    ungroup() %>%
    arrange(desc(n)) %>%
    mutate(order = row_number())
ggplot(f3_fsa, aes(x = n)) + geom_histogram(bins = 15) + theme_minimal() +
    labs(title = "Change detection ensemble histogram")
ggplot(f3_fsa, aes(x = 1, y = n)) + geom_violin(fill = "green") + 
    theme_minimal() + 
    geom_jitter(shape = 16, position = position_jitter(0.1), size = 1,
    alpha = 0.5, col = "red") + 
    labs(title = "Change detection ensemble violin jitter")

ggplot(f3_fsa, aes(x = order, y = n)) + geom_line() + geom_point(col = "red") + 
    theme_minimal() +
    labs(title = "Change detection ensemble elbow plot")


hit_list_fsa <- f3_fsa %>%
    filter(order <= 2) %>%
    mutate(Neighbourhood = 
        ifelse(pc == "M5K", "Downtown Toronto (TD Centre / Design Exchange)",
        ifelse(pc == "M1K", "Scaborough (Kennedy Park / Ionview / East Birchmount Park)",
        ifelse(pc == "M5H", "Downtown Toronto (Richmond / Adelaide / King)",
        ifelse(pc == "M2N", "North York (Willowdale) South",
        ifelse(pc == "M8X", "Etobicoke (Kingsway / Montgomery Rd / Old Mill North",
        ifelse(pc == "M5J", "Downtown Toronto (Harbourfront East / Union St / Toronto Islands",
        ifelse(pc == "L3R", "Markham (Outer Southwest)",
        ifelse(pc == "L4W", "Mississauga (Matheson / East Rathwood)",
        ifelse(pc == "V6Y", "Richmond Central",
        ifelse(pc == "V6X", "Richmond North",
        ifelse(pc == "H3B", "Downtown Montreal East", "UK")))))))))))) %>%
    select(pc, Neighbourhood, order)
print(hit_list_fsa)

# sector-level and FSA-level model ----------------------------------------
# business- and FSA-lvl CUSUM with T and C hyperparam grid search
tmp_mu <- f1 %>%
    group_by(pc, sector) %>%
    summarise(mu = mean(rep_num)) %>%
    ungroup()
# 493 is max mu, 36922 is max st when C==0, >9 trillion combinations of C-T-FSA
# ggplot(tmp_mu, aes(x = mu)) + geom_histogram() + theme_minimal()
# ggplot(f2_fsa_sector, aes(x = st)) + geom_histogram() + theme_minimal()
cusum_fsa_sector <- function(C, T) {
    tmp_fsa <- f1 %>%
        group_by(pc, sector, rep_dt) %>%
        summarise(rep_num = sum(rep_num)) %>%
        ungroup() %>%
        arrange(pc, sector, rep_dt) %>%
        left_join(tmp_mu, by = c("pc", "sector")) %>%
        group_by(pc, sector) %>%
        mutate(
            xt = ifelse(is.na(lag(rep_num, n = 1)), rep_num, 
                lag(rep_num, n = 1)),
            cum_sum = cumsum(xt),
            tmp = ifelse(is.na(
                lag(cum_sum, n = 1) + (xt - mu - C)), mu,
                lag(cum_sum, n = 1) + (xt - mu - C))) %>%
        ungroup() %>%
        rowwise() %>%
        mutate(
            st = max(0, tmp),
            chg_ind = ifelse(st >= T, "Y", "N")) %>%
        ungroup() %>%
        arrange(pc, sector) %>%
        group_by(pc, sector) %>%
        filter(row_number() >= (n() - 1)) %>%
        ungroup() %>%
        group_by(pc, sector) %>%
        filter(chg_ind == "Y" & lag(chg_ind, n = 1) == "N") %>%
        ungroup() %>%
        select(pc, sector, chg_ind)
    invisible(as_tibble(tmp_fsa))
}
hyperparams = list(
    C = seq(0, 500, by = 50),
    T = seq(0, 40000, by = 5000))
f2_fsa_sector <- cusum_fsa_sector(C = 999, T = 99999)  # create empty tibble to row_bind
for (i in hyperparams$C) {
    for (j in hyperparams$T) {
        tmp <- cusum_fsa_sector(C = i, T = j)
        f2_fsa_sector <- f2_fsa_sector %>% 
        bind_rows(tmp)}}
f3_fsa_sector <- f2_fsa_sector %>%
    group_by(pc, sector) %>%
    count() %>%
    ungroup() %>%
    arrange(sector, desc(n), pc)
ggplot(f3_fsa_sector, aes(x = sector, y = n)) + geom_violin(fill = "green") + 
    theme_minimal() + coord_flip() +
    geom_jitter(shape = 16, position = position_jitter(0.2), size = 2,
    alpha = 0.8, col = "red") +
    labs(title = "Change detection elbow jitter")

# 1 bank
hit_list_fsa_sector <- f3_fsa_sector %>%
    filter(sector %in% c("BANK") & n >= 9) %>%
    mutate(Neighbourhood = 
        ifelse(pc == "M1K", "Scaborough (Kennedy Park / Ionview / East Birchmount Park)",
        ifelse(pc == "M2H", "North York (Hillcrest Village)",
        ifelse(pc == "M4V", "Central Toronto (Summerhill West / Rathnelly / South Hill / Forest Hill SE / Deer Park",
        ifelse(pc == "M3M", "North York (Downsview) Central",
        ifelse(pc == "M9V", "Etobicoke (South Steeles / Silverstone / Humbergate / Jamestown / Mount Olive / Thistletown / Albion Gardens",
        ifelse(pc == "M4W", "Downtown Toronto (Rosedale)",
        ifelse(pc == "V3W", "Surrey Upper West",
        ifelse(pc == "V6C", "Vancouver (Waterfront / Coal Harbour / Canada Place", 
            "UK"))))))))) %>%
    arrange(desc(n)) %>%
    mutate(order = row_number()) %>%
    select(pc, sector, Neighbourhood, order)
print(hit_list_fsa_sector)

# hit list viz ------------------------------------------------------------
tmp <- f1 %>%
    left_join(hit_list_fsa, by = "pc") %>%
    mutate(grp = ifelse(is.na(order), "All", as.character(order))) %>%
    group_by(grp, rep_dt) %>%
    summarise(rep_num = sum(rep_num)) %>%
    ungroup() 
tmp_means <- tmp %>%
    group_by(grp) %>%
    summarise(grp_mean = mean(rep_num)) %>%
    ungroup()
tmp <- tmp %>%
    left_join(tmp_means, by = "grp") %>%
    mutate(rep_num_index = rep_num / grp_mean)
ggplot(tmp, aes(x = rep_dt, y = rep_num_index, group = grp)) + 
    geom_line(aes(col = grp), size = 2) + theme_void() + 
    labs(title = "Top 2 most suspicious FSA neighbourhoods vs all observations (both indexed)")

tmp <- f1 %>%
    left_join(hit_list_fsa_sector, by = c("pc", "sector")) %>%
    mutate(grp = ifelse(is.na(order), "All", as.character(order))) %>%
    group_by(grp, rep_dt) %>%
    summarise(rep_num = sum(rep_num)) %>%
    ungroup() 
tmp_means <- tmp %>%
    group_by(grp) %>%
    summarise(grp_mean = mean(rep_num)) %>%
    ungroup()
tmp <- tmp %>%
    left_join(tmp_means, by = "grp") %>%
    mutate(rep_num_index = rep_num / grp_mean)

ggplot(tmp, aes(x = rep_dt, y = rep_num_index, group = grp)) + 
    geom_line(aes(col = grp), size = 2) + theme_void() + 
    labs(title = "Top 1 most suspicious neighbourhood-sector combination vs all observations (both indexed)")

