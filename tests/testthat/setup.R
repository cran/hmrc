# Keep every test away from the user's real cache. Files downloaded by the
# live tests are shared across the run and removed with the temp directory.
withr::local_options(
  list(hmrc.cache_dir = file.path(tempdir(), "hmrc-tests")),
  .local_envir = testthat::teardown_env()
)
