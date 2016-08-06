# NPM Required:
#  coffee-script
#  uglify-js

`coffee -o stdlib/JS -c stdlib/JS/fwi.coffee`
`uglifyjs --compress --mangle --support-ie8 -o stdlib/JS/fwi.min.js -- stdlib/JS/fwi.js`

