xquery version "3.0";

import module namespace config="http://e-smile.org/common/config" at "/db/apps/esmile/common/modules/config.xqm";
import module namespace tplu = "http://e-smile.org/common/templates-utils" at "/db/apps/esmile/common/modules/templates-utils.xqm";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "text";
declare option output:media-type "application/json";

let $content := util:binary-to-string(request:get-data())
(:let $key := config:app-key():)
let $map := config:manifest-map()

return
(:    string-join(tplu:expand-template(<root>{$content}</root>, map {"app-key" := $key})) :)
    string-join(tplu:expand-template(<root>{$content}</root>, $map)) 
