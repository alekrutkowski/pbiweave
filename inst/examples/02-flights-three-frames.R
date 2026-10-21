# A complete intermediate tutorial: exactly three input data.frames.
# install.packages(c("data.table", "nycflights13"))
library(pbiweave)
library(data.table)

flights <- as.data.frame(nycflights13::flights)
airlines <- as.data.frame(nycflights13::airlines)
airports <- as.data.frame(nycflights13::airports)

# Grain: one row per date x carrier x origin x destination x departure period.
# All cleaning, feature engineering, and preaggregation take place in R.
facts <- flights %>% pbi_prepare(function(d) d %>%
  .[, `:=`(
    flight_date = as.Date(sprintf("%04d-%02d-%02d", year, month, day)),
    departure_band = fcase(hour < 6, "01 Overnight", hour < 12, "02 Morning",
                           hour < 18, "03 Afternoon", default = "04 Evening")
  )] %>%
  .[, .(
    flight_count = .N,
    arrivals_observed = sum(!is.na(arr_delay)),
    late_arrivals = sum(arr_delay >= 15, na.rm = TRUE),
    arrival_delay_sum = sum(arr_delay, na.rm = TRUE),
    distance_sum = sum(distance, na.rm = TRUE)
  ), by = .(flight_date, carrier, origin, dest, departure_band)])

airline_dim <- airlines %>% pbi_prepare(function(d) d[, .(carrier, airline = name)])
airport_dim <- airports %>% pbi_prepare(function(d) d %>%
  .[faa %chin% unique(facts$dest)] %>%
  .[, .(dest = faa, airport = paste0(name, " [", faa, "]"), latitude = lat, longitude = lon, time_zone = tzone)])

# A left-safe dimension: retain every destination key present in the fact table.
# Never silently drop flights because metadata for a destination is absent.
missing_dest <- setdiff(unique(facts$dest), airport_dim$dest)
if (length(missing_dest)) {
  airport_dim <- rbindlist(list(
    airport_dim,
    data.table(dest = missing_dest, airport = paste("Unlisted destination", missing_dest),
               latitude = NA_real_, longitude = NA_real_, time_zone = NA_character_)
  ), use.names = TRUE)
}
stopifnot(!anyDuplicated(airline_dim$carrier), !anyDuplicated(airport_dim$dest),
          all(facts$carrier %chin% airline_dim$carrier), all(facts$dest %chin% airport_dim$dest),
          sum(facts$flight_count) == nrow(flights))

# Ratios need selection-time division of R-computed sufficient statistics.
# mean(cell_means) would be wrong whenever cells have different row counts.
expected <- facts[, .(
  flights = sum(flight_count),
  late_rate = sum(late_arrivals) / sum(arrivals_observed),
  mean_arrival_delay = sum(arrival_delay_sum) / sum(arrivals_observed)
)]
stopifnot(isTRUE(all.equal(expected$late_rate,
                          mean(flights$arr_delay >= 15, na.rm = TRUE))))
print(expected)

dashboard <- pbi_dashboard("Airline and destination performance", facts,
                            table = "Flights", theme = "ocean") %>%
  pbi_data("Airlines", airline_dim, description = "One row per airline code") %>%
  pbi_data("Airports", airport_dim, description = "One row per destination, including unknown metadata") %>%
  pbi_relationship("Flights", "carrier", "Airlines", "carrier", unmatched = "error") %>%
  pbi_relationship("Flights", "dest", "Airports", "dest", unmatched = "error") %>%
  pbi_column("latitude", table = "Airports", data_category = "Latitude", summarize = "none") %>%
  pbi_column("longitude", table = "Airports", data_category = "Longitude", summarize = "none") %>%
  pbi_ratio("Late-arrival rate", "late_arrivals", "arrivals_observed", format = "0.0%") %>%
  pbi_ratio("Mean arrival delay", "arrival_delay_sum", "arrivals_observed", format = "0.0") %>%
  pbi_page(
    "Performance",
    pbi_slicer("airline", table = "Airlines", title = "Airline", sync = "airline"),
    pbi_slicer("airport", table = "Airports", title = "Destination", sync = "airport"),
    pbi_slicer("flight_date", title = "Date range", style = "between", sync = "date"),
    pbi_card("flight_count", title = "Flights"),
    pbi_card(pbi_ref("Late-arrival rate"), title = "Late-arrival rate"),
    pbi_line("flight_date", pbi_ref("Mean arrival delay"), title = "Daily mean arrival delay"),
    pbi_bar(pbi_field("airline", "Airlines"), pbi_ref("Late-arrival rate"),
            title = "Late-arrival rate by airline"),
    layout = pbi_layout("sidebar", sidebar_mode = "slicers"), interactions = "filter"
  ) %>%
  pbi_page(
    "Destinations",
    pbi_slicer("airline", table = "Airlines", title = "Airline", sync = "airline"),
    pbi_slicer("airport", table = "Airports", title = "Destination", sync = "airport"),
    pbi_slicer("flight_date", title = "Date range", style = "between", sync = "date"),
    pbi_bar(pbi_field("airport", "Airports"), "flight_count", title = "Flight volume"),
    pbi_matrix(pbi_field("airline", "Airlines"), pbi_ref("Mean arrival delay"),
               columns = "origin", title = "Average delay by airline and origin"),
    pbi_table(c("flight_date", "origin", "carrier", "dest", "departure_band",
                "flight_count", "arrivals_observed", "late_arrivals"), title = "Auditable R-prepared cells"),
    layout = pbi_layout("sidebar", sidebar_mode = "slicers")
  )

pbi_validate(dashboard)
project <- pbi_compile(dashboard, "nyc-flights-three-frames", bundle = TRUE)
stopifnot(pbi_check(project)$valid)
# pbi_open(project)
# REQUIRED IN DESKTOP: Home -> Refresh, clear slicers, compare expected, Save As .pbix.
