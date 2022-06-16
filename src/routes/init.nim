import prologue

import ./index
import ./read
import ./search


proc mountRoutes*(app: var Prologue) =
  app.get("/", indexRoute)
  app.get("/search", searchRoute)
  app.get("/{path}$", readRoute)
