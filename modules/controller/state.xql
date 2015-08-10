(: Return the state of application  :)

xquery version "3.0";


(:import module namespace config="$$config-namespace$$" at "../modules/config.xqm";:)
(:import module namespace app="$$namespace$$" at "../modules/app.xql";:)
(:import module namespace sencha="http://e-smile.org/sencha" at "../../common/modules/sencha.xqm";:)

import module namespace config="http://e-smile.org/es-admin/config" at "../config.xqm";
(:import module namespace app="http://e-smile.org/es-desktop/templates" at "../app.xql";:)
import module namespace state="http://e-smile.org/common/state" at "../../../common/modules/state.xqm";
import module namespace mapxt="http://e-smile.org/common/map-extensions" at "../../../common/modules/map-extensions.xqm";


declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
(:declare namespace err="http://www.w3.org/2005/xqt-errors/";:)
declare option output:method "json";
declare option output:media-type "application/json";

try {
    let $method := request:get-method()
    let $app := config:app-name() 
    let $state := state:get($app)

    let $log := util:log-system-out(("state : app ", $app))  
    (:let $log := util:log-system-out(("requestData ",request:get-data()))  :)
    (:let $log := util:log-system-out(("session:  ",session:get-id()))  :)


    let $check-init := if(empty($state)) (:if state is empty, we need to initiate it:)
        then (state:init($app,(config:app-state(),  $config:expath-descriptor))) 
        else ($state)
    let $state := if($method = "POST") 
        then (state:set($app, mapxt:request-to-map())) 
        else ($check-init)
(:    let $log := util:log-system-out(("STATE:  ",$config:expath-descriptor, mapxt:to-el($state)))  :)
    
    
     
    return 
    
        mapxt:to-el($state)        

} catch * {
     response:set-status-code(401),
    <status>{$err:description}</status>
}


