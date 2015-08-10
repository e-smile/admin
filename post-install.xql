xquery version "3.0";

import module namespace templates="http://exist-db.org/xquery/templates";
import module namespace config= "http://e-smile.org/common/config" at "modules/config.xqm";

import module namespace inst= "http://e-smile.org/common/inst" at "modules/install/inst.xqm";

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

let $config := map {
    $templates:CONFIG_APP_ROOT := $config:app-root, 
    $templates:CONFIG_STOP_ON_ERROR := false() 
}
(: 
 : We have to provide a lookup function to templates:apply to help it
 : find functions in the imported application modules. The templates 
 : module cannot see the application modules, but the inline function
 : below does see them.
 :)
let $lookup := function($functionName as xs:string, $arity as xs:int) {
    try {
        function-lookup(xs:QName($functionName), $arity)
    } catch * {
        ()
    }
}

let $target := $config:app-root
let $col := $target || "/data/install"
let $instalTpl := doc($col || "/instalTpl.xml")
let $model := map {
    "install.dir" := $dir,
    "install.home" := $home,
    "install.target" := $target
}

let $log := templates:apply($instalTpl, $lookup, $model, $config)
let $store := xmldb:store($col, "instalLog.xml", $log)
return $log


