-- Rewrites repo-relative links (../../terraform/...) to GitHub URLs so they
-- still work inside a downloaded PDF.
local base = "https://github.com/Here2ServeU/building-ai-infra/tree/main/"

function Link(el)
  local t = el.target
  if t:match("^%.%./%.%./") then
    el.target = base .. t:gsub("^%.%./%.%./", "")
  elseif t:match("^%.%./") then
    el.target = base .. "docs/" .. t:gsub("^%.%./", "")
  elseif not t:match("^%a+:") and not t:match("^#") then
    el.target = base .. "docs/series/" .. t
  end
  return el
end
