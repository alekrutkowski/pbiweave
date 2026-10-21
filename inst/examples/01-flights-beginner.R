# A complete beginner tutorial. Run from a directory where you can create output.
# install.packages(c("data.table", "nycflights13"))
library(pbiweave)
library(data.table)

# A genuine ordinary data.frame, with 19 source variables.
flights <- as.data.frame(nycflights13::flights)
stopifnot(ncol(flights) == 19L, nrow(flights) == 336776L)

# Every transformation below happens in R, once, before compilation.
# Keep unknown arrival outcomes as NA: they must not count as on-time arrivals.
prepared <- flights %>%
  pbi_prepare(function(d) d %>%
    .[, `:=`(
      flight_id = seq_len(.N),
      flight_date = as.Date(sprintf("%04d-%02d-%02d", year, month, day)),
      flight_count = 1L,
      arrival_observed = as.integer(!is.na(arr_delay)),
      late_15 = fifelse(is.na(arr_delay), NA_real_, as.numeric(arr_delay >= 15)),
      departure_band = fcase(hour < 6, "01 Overnight", hour < 12, "02 Morning",
                             hour < 18, "03 Afternoon", default = "04 Evening"),
      distance_band = fcase(distance < 500, "01 Under 500 miles", distance < 1500,
                            "02 500-1499 miles", default = "03 1500+ miles")
    )] %>%
    .[, .(flight_id, flight_date, month, carrier, origin, dest, departure_band,
           distance_band, distance, air_time, dep_delay, arr_delay,
           flight_count, arrival_observed, late_15)])

# The reference values are computed in R, not copied from an unverified screenshot.
expected <- prepared[, .(
  flights = sum(flight_count),
  observed_arrivals = sum(arrival_observed),
  late_rate = mean(late_15, na.rm = TRUE),
  mean_arrival_delay = mean(arr_delay, na.rm = TRUE)
)]
print(expected)

# Basic aggregation remains native so slicer choices update totals correctly.
# No handwritten DAX is needed for this observation-level model.
dashboard <- pbi_dashboard("NYC flights | 2013", prepared, table = "Flights", theme = "midnight") %>%
  pbi_column("late_15", format = "0.0%") %>%
  pbi_column("arr_delay", format = "0.0") %>%
  pbi_column("flight_id", hidden = TRUE, summarize = "none") %>%
  pbi_page(
    "Overview",
    pbi_slicer("origin", title = "Origin airport", sync = "origin"),
    pbi_slicer("carrier", title = "Carrier", sync = "carrier"),
    pbi_slicer("flight_date", title = "Date range", style = "between", sync = "date"),
    pbi_card("flight_count", title = "Flight records"),
    pbi_card(pbi_aggregate("late_15", "average"), title = "Late arrivals | 15+ minutes"),
    pbi_line("flight_date", "flight_count", title = "Flights per day"),
    pbi_bar("carrier", pbi_aggregate("arr_delay", "average"), title = "Mean arrival delay | minutes"),
    layout = pbi_layout("sidebar", columns = 2, sidebar_mode = "slicers"), interactions = "filter"
  ) %>%
  pbi_page(
    "Explore routes",
    pbi_slicer("origin", title = "Origin airport", sync = "origin"),
    pbi_slicer("carrier", title = "Carrier", sync = "carrier"),
    pbi_slicer("flight_date", title = "Date range", style = "between", sync = "date"),
    pbi_bar("dest", "flight_count", title = "Flight volume by destination"),
    pbi_matrix("departure_band", pbi_aggregate("late_15", "average"),
               columns = "origin", title = "Late-arrival rate by departure period"),
    pbi_bar("distance_band", pbi_aggregate("arr_delay", "average"),
            title = "Mean delay by distance band"),
    pbi_table(c("flight_id", "flight_date", "carrier", "origin", "dest", "dep_delay", "arr_delay"),
              title = "Detail | filter before inspecting"),
    layout = pbi_layout("sidebar", columns = 2, sidebar_mode = "slicers")
  )

pbi_validate(dashboard)
project <- pbi_compile(dashboard, "nyc-flights-beginner", bundle = TRUE)
stopifnot(pbi_check(project)$valid)
# Opening is optional in automated runs. On Windows, uncomment:
# pbi_open(project)
# REQUIRED IN DESKTOP: Home -> Refresh. Then inspect and File -> Save As -> .pbix.
