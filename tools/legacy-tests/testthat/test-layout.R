test_that("grid spans pack without overlap or out-of-bounds positions", {
  x <- pbi_dashboard("Layouts", mtcars) %>%
    pbi_page("Grid", pbi_card("mpg") %>% pbi_span(columns = 2),
             pbi_bar("cyl", "mpg") %>% pbi_span(rows = 2),
             pbi_table(c("cyl", "mpg")), pbi_table("hp"),
             layout = pbi_layout(columns = 3))
  positions <- pbiweave:::layout_page(x$pages[[1]])
  expect_length(positions, 4L)
  expect_gt(positions[[1]]$width, positions[[2]]$width)
  expect_equal(nrow(pbi_validate(x)), 0L)
  expect_error(pbi_page(x, "Overspan", pbi_card("mpg") %>% pbi_span(columns = 3)), "exceeds")
})

test_that("sidebar and focus reserve their first visual", {
  base <- pbi_dashboard("Layout", mtcars)
  sidebar <- base %>% pbi_page("Side", pbi_slicer("cyl"), pbi_card("mpg"),
                              pbi_card("hp"), layout = pbi_layout("sidebar"))
  p <- pbiweave:::layout_page(sidebar$pages[[1]])
  expect_gt(p[[2]]$x, p[[1]]$x + p[[1]]$width)
  focus <- base %>% pbi_page("Focus", pbi_line("cyl", "mpg"), pbi_card("mpg"),
                            pbi_card("hp"), layout = pbi_layout("focus"))
  p <- pbiweave:::layout_page(focus$pages[[1]])
  expect_gt(p[[2]]$y, p[[1]]$y + p[[1]]$height)
})

test_that("free positioning is checked before output is written", {
  base <- pbi_dashboard("Layout", mtcars)
  expect_error(pbi_page(base, "Free", pbi_card("mpg"), layout = "free"), "pbi_place")
  expect_error(pbi_page(base, "Free", pbi_card("mpg") %>% pbi_place(1200, 600, 400, 300),
                        layout = "free"), "beyond")
  expect_error(pbi_page(base, "Grid", pbi_card("mpg") %>% pbi_place(20, 20, 200, 100)), "free layout")
  free <- base %>% pbi_page("Free",
    pbi_card("mpg") %>% pbi_place(20, 20, 200, 100),
    pbi_card("hp") %>% pbi_place(50, 40, 200, 100), layout = pbi_layout("free", header = 0))
  expect_true("overlap" %in% pbi_validate(free)$code)
})
