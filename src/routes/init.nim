import prologue

import ./index
import ./read
import ./search
import ./atom


proc mountRoutes*(app: var Prologue) =
  app.get("/", indexRoute)
  app.get("/search", searchRoute)
  app.get("/atom.xml", atomRoute)
  app.get("/{path}$", readRoute)
