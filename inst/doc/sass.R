## ----setup, include = FALSE----------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----echo = FALSE--------------------------------------------------------
knitr::include_app("https://gallery.shinyapps.io/sass-color", height = "600px")

## ----echo = FALSE--------------------------------------------------------
knitr::include_app("https://gallery.shinyapps.io/sass-font/", height = "400px")

## ----echo = FALSE--------------------------------------------------------
knitr::include_app("https://gallery.shinyapps.io/sass-size/", height = "600px")

## ------------------------------------------------------------------------
new_style <- "
  $color: #FFFFFF;
  $width: 100;

  body {
    background-color: $color;
  }

  // https://stackoverflow.com/a/3943023/6637133
  @function font-color($color) {
    @return if(
      red($color) * 0.299 + green($color) * 0.587 + blue($color) * 0.114 > 186,
      #000000, #ffffff
    );
  }

  h1 {
    color: font-color($color);
  }

  .shiny-plot-output {
    max-width: percentage($width / 100);
  }
"

## ------------------------------------------------------------------------
library(sass)
sass(new_style, options = sass_options(output_style = "compressed"))

