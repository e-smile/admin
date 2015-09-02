xquery version "3.0";

import module namespace common-config="http://e-smile.org/common/config" at "/db/apps/esmile/common/modules/config.xqm";
import module namespace config="http://e-smile.org/es-admin/config" at "modules/config.xqm";
import module namespace state="http://e-smile.org/common/state" at "/db/apps/esmile/common/modules/state.xqm";
import module namespace login-helper="http://exist-db.org/apps/dashboard/login-helper" at "/db/apps/esmile/common/modules/login-helper.xqm";

declare variable $login := login-helper:get-login-method();


declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;


(:let $log := util:log-system-out(("u: ", xmldb:get-current-user(),', ',request:get-attribute($local:app.domain || ".user"),', ', request:get-attribute("xquery.user"))):)
(:let $log := util:log-system-out(("cookies: ", request:get-cookie-value($local:app.domain))) :)
(:let $log := util:log-system-out(("app-mode: ",$local:app.mode )):)

if ($exist:path eq '') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{request:get-uri()}/"/>
    </dispatch>
    

else if ($exist:path eq "/") then
    (: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>

 else if (contains($exist:path, '/$controller/state')) then 
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <!--forward  url="/../apps/esmile/{local:app-name($exist:path)}/modules/controller/state.xql" -->
            <forward  url="{$exist:controller}/modules/controller/state.xql" >
                {$login("org.esmile.login", (), false())}
            </forward>
    </dispatch>

(: Resource paths starting with $controller are loaded from the controller :)
else if (contains($exist:path, "/$controller/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward  url="{$exist:controller}/modules/controller/{$exist:resource}.xql" >
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>

(: Resource paths starting with $commonc are loaded from the common app controller :)
else if (contains($exist:path, "/$commonc/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/../apps/esmile/common/modules/controller/{$exist:resource}.xql">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>  

(: Resource paths starting with $commonr are loaded from the common resources :)
else if (contains($exist:path, "/$commonr/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/esmile/common/resources/{substring-after($exist:path, '/$commonr/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>

(: Resource paths starting with $shared are loaded from the shared-resources app :)
else if (contains($exist:path, "/$shared/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/shared-resources/{substring-after($exist:path, '/$shared/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>
    

else if ($exist:resource = "app.json") then
<dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="{$exist:controller}/views/manifest.xql">
                <!-- Need to overwrite content length otherwise, error in chrome -->
                <set-header name="Content-Length" value="-1"/>
            </forward>
        </view>
		<error-handler>
			<forward url="{$exist:controller}/error-page.html" method="get"/>
			<forward url="{$exist:controller}/views/view.xql"/>
		</error-handler>
    </dispatch>  

(: images, css are contained in the top /resources/ collection. :)
(: Relative path requests from sub-collections are redirected there :)
else if (contains($exist:path, "/$resources/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/resources/{substring-after($exist:path, '/$resources/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch> 

else if (ends-with($exist:resource, ".html")) then (
    (: the html page is run through view.xql to expand templates :)
    let $app-name := config:app-name()
    let $state := state:get($app-name)
    let $init := if(empty($state)) then (state:init($app-name,(config:app-state(),$config:expath-descriptor)))  else ($state)
    let $path := $config:app-root || $exist:path

    
(:let $log := util:log-system-out(("path: ",$exist:path ))    :)
(:let $log := util:log-system-out(("path: ",$exist:path )):)
(:let $log := util:log-system-out(("resource: ",$exist:resource )):)
(:let $log := util:log-system-out(("controller: ",$exist:controller )):)
(:let $log := util:log-system-out(("prefix: ",$exist:prefix )):)
(:let $log := util:log-system-out(("root: ",$exist:root )):)
    
    return 
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="{$exist:controller}/views/view.xql">
                <set-header name="App-Key" value="{common-config:app-key()}"/>
                <set-header name="App-Mode" value="{config:app-mode()}"/>
                <set-header name="App-Name" value="{$app-name}"/>
                <set-header name="App-Token" value="{$init('token')}"/>
                <set-header name="App-Counter" value="{$init('counter')}"/>
                <set-attribute  name="{$common-config:resource.path}" value="{$path}"/>
                <set-header name="Access-Control-Allow-Origin" value="https://www.e-smile.org"/> 
                <set-header name="Access-Control-Allow-Origin" value="https://e-smile.org"/>
            </forward>
        </view>
		<error-handler>
			<forward url="{$exist:controller}/error-page.html" method="get"/>
			<forward url="{$exist:controller}/views/view.xql"/>
		</error-handler>
    </dispatch>
    )
else
    (: everything else is passed through :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>
