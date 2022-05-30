import prologue

import ./index
import ./read


proc mountRoutes*(app: var Prologue) =
  app.get("/", indexRoute)
  app.get("/{path}$", readRoute)