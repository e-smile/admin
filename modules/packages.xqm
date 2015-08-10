xquery version "3.0";

module namespace packages="http://e-smile.org/es-admin/packages";

import module namespace config="http://e-smile.org/es-admin/config" at "config.xqm";
import module namespace glc="http://e-smile.org/common/global-config" at "/db/apps/esmile/common/modules/global-config.xqm";
import module namespace functx = "http://www.functx.com" ;

declare namespace json="http://www.json.org";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace expath="http://expath.org/ns/pkg";
declare namespace repo="http://exist-db.org/xquery/repo";

declare namespace http="http://expath.org/ns/http-client";

declare variable $packages:DEFAULTS := doc($config:app-root || "/defaults.xml")/apps;
declare variable $packages:HIDE := ("dashboard", "__master");

declare variable $packages:format-app := "esmileApp" ;
declare variable $packages:format-ms :=  "monitoringSpace"  ;



(:~
 : Get list of packages (apps and plugins) 
 : @param $type "local" or "remote" or "all" for both
 : @param $format "esmileApp" for esmile application or "monitoringSpace"
 : @param $plugins select plugins if 
 :)

declare function packages:get($type as xs:string?, $format as xs:string?, $plugins as xs:string?) {
    let $apps := packages:default-apps($plugins) | packages:installed-apps($format)
(:     let $apps :=  packages:installed-apps($format):)
(:    let $log := util:log-system-out(("apps: ",$apps)) :)
    let $apps := switch ($type)
        case "local" 
            return ($apps)
        case "remote" 
            return (packages:public-repo-contents($apps, $format))
        default return 
            ($apps, packages:public-repo-contents($apps, $format))
        
(:     let $log := util:log-system-out(("CONFIG: ", $config:REPO))    :)
    let $apps := if ($format = "manager") then $apps except $apps[@removable="no"] else $apps
(:    let $log := util:log-system-out(("apps manager: ",$apps)) :)
    for $app in $apps
     
(:    order by upper-case($app/title/text()):)
         
    return 
         packages:display($config:DEFAULTREPO, $app, $format)
(:        for $repo in $config:REPO/url:)
(:        return :)
(:        packages:display(xs:anyURI($repo), $app, $format):)
};


declare %private function packages:display($repoURL as xs:anyURI?, $app as element(app), $format as xs:string?) {
(:    let $log := util:log-system-out($app):)
    let $icon := data(
        if ($app/icon) then
            if ($app/@status) then
                $app/icon[1]
            else
                $repoURL || "/public/" || $app/icon[1]
        else
            "resources/images/package.png")
    let $url :=
        if ($app/url) then
            data($app/url)
        else
            data($app/@path)
    let $installed := $app/@installed/string()
    let $available := $app/@available/string()
    let $hasNewer := 
            if ($app/@available) then
                packages:is-newer($available, $installed)
            else
                false()        
    return
        <app>{$app/@*}{$app/* except ($app/icon, $app/url)}<icon>{$icon}</icon><url>{$url}</url></app>
        
};

declare %private function packages:default-apps($plugins as xs:string?) {
    if ($plugins) then
        $packages:DEFAULTS/app
    else
        filter(function($app as element(app)) {
            if ($app/type = 'plugin') then
                ()
            else
                $app
        }, $packages:DEFAULTS/app)
};

(:~
 : Determines if the package is an esmile app
 : For the time being, naive assertion that is is deployed under /apps/esmile
 :)
declare %private function packages:is-esmile($app,  $format as xs:string? ,$expathXML, $repoXML) {
    switch ($format)
        case $packages:format-app
            return starts-with($repoXML//repo:target, $glc:esmile || '/')
        case $packages:format-ms
            return starts-with($repoXML//repo:target, $glc:esmileSpace || '/')    
        default return true()
    
};

(:~
 : Determines if the package is an esmile app
 : For the time being, naive assertion that is is deployed under /apps/esmile
 :)
declare %private function packages:is-hidden($app,  $format as xs:string? ,$expathXML, $repoXML) {
    contains($repoXML//repo:target, $packages:HIDE)
};
(:~
 : Determines if the package is an esmile monitoring space
 : For the time being, naive assertion that is is deployed under /apps/esmileSpace
 :)
declare %private function packages:is-data($app, $format as xs:string) as xs:string {
    xs:string($format = $packages:format-ms)
};


declare %private function packages:installed-apps($format as xs:string?) as element(app)* {
    packages:scan-repo(
        function ($app, $expathXML, $repoXML) {
            if(packages:is-esmile($app, $format,  $expathXML, $repoXML) and not(packages:is-hidden($app,$format, $expathXML, $repoXML))) 
            then (
(:                if ($format = "manager" or $repoXML//repo:type = "application") then:)
                    let $icon :=
                        let $iconRes := repo:get-resource($app, "icon.png")
                        let $iconSvgRes := repo:get-resource($app, "icon.svg")
                        let $iconSvg := doc-available(repo:get-root() ||"/"  || $app || "/icon.svg")
                        let $hasIcon := exists(($iconRes, $iconSvgRes, $iconSvg))
                        return
                            $hasIcon
                    let $app-url :=
                        if ($repoXML//repo:target) then
                            let $target := 
                                if (starts-with($repoXML//repo:target, "/")) then
                                    replace($repoXML//repo:target, "^/.*/([^/]+)", "$1")
                                else
                                    $repoXML//repo:target
                            return
                                replace(
                                    request:get-context-path() || "/" || request:get-attribute("$exist:prefix") || "/" || $target || "/",
                                    "/+", "/"
                                )
                        else
                            ()
                    let $target := $repoXML//repo:target,   
                        $name := $expathXML//@name/string(),
                        $abbrev := $expathXML//@abbrev/string()
(:                    let $test := functx::)

                    return
                        let $ret := 
                        <app status="installed" path="{$expathXML//@name}" required="{$repoXML//@required}">
                            
                            <title>{$expathXML//expath:title/text()}</title>
                            <name>{$name}</name>
                            <description>{$repoXML//repo:description/text()}</description>
                            {
                                for $author in $repoXML//repo:author
                                return
                                    <author>{$author/text()}</author>
                            }
                            <abbrev>{$abbrev}</abbrev>
                            <website>{$repoXML//repo:website/text()}</website>
                            <version>{$expathXML//expath:package/@version/string()}</version>
                            <license>{$repoXML//repo:license/text()}</license>
                            <icon>{if ($icon) then '$commonc/package-icon?app=' || $name else 'resources/images/e-smile-icon.svg'}</icon>
                            <!--path>{repo:get-root()  || $target || "/resources/images/app-icon.svg"}</path-->
                            <target>{repo:get-root()  || $target}</target>
                            <svgIcon>{util:expand(doc(repo:get-root()  || $target || "/resources/images/app-icon.svg")) }</svgIcon>
                            <url>{$app-url}</url>
                            <type>{$repoXML//repo:type/text()}</type>
                            <isData>{packages:is-data($app, $format)}</isData> 
                            {functx:change-element-ns-deep($repoXML//repo:changelog, "", "")}
                            {functx:change-element-ns-deep($repoXML/*/(repo:note,repo:other,repo:tags, repo:category, repo:github ), "", "")} 
                            {if($format = $packages:format-ms) then (
                                    let $content := doc(repo:get-root()  || $target || '/configuration.xml')/*
                                    return if($content) 
                                    then <msConfiguration>{$content}</msConfiguration>
                                    else ()
                                ) else () }
                        </app>
                        return $ret
(:                else:)
(:                    ():)
            )
            else ()
        }
    )
};

declare %private function packages:scan-repo($callback as function(xs:string, element(), element()?) as item()*) {
    for $app in repo:list()
    let $expathMeta := packages:get-package-meta($app, "expath-pkg.xml")
    let $repoMeta := packages:get-package-meta($app, "repo.xml")
    return
        $callback($app, $expathMeta, $repoMeta)
};

declare %private function packages:get-package-meta($app as xs:string, $name as xs:string) {
    let $data :=
        let $meta := repo:get-resource($app, $name)
        return
            if (exists($meta)) then util:binary-to-string($meta) else ()
    return
        if (exists($data)) then
            util:parse($data)
        else
            ()
};

declare %private function packages:public-repo-contents($installed as element(app)*, $format as xs:string) {
    try {
        for $repo in $config:REPO
        let $public := if($format = $packages:format-app) then "/public/apps.xml" else "/public/ms.xml"
        let $url := $repo/url || $public
(:        let $url := $config:REPO || "/public/apps.xml":)
        (: EXPath client module does not work properly. No idea why. :)
(:        let $request :=:)
(:            <http:request method="get" href="{$url}" timeout="10">:)
(:                <http:header name="Cache-Control" value="no-cache"/>:)
(:            </http:request>:)
(:        let $data := http:send-request($request):)
        let $data := httpclient:get($url, false(), ())
        let $status := xs:int($data/@statusCode)
(:        let $log := util:log-system-out(("STATUS: ", $status)):)
        return
            if ($status != 200) then
                response:set-status-code($status)
            else
                map(function($app as element(app)) {
                    (: Ignore apps which are already installed :)
                    if ($app/abbrev = $installed/abbrev) then
                        if (packages:is-newer($app/version/string(), $installed[abbrev = $app/abbrev]/version)) then
                            element { node-name($app) } {
                                attribute available { $app/version/string() },
                                attribute installed { $installed[abbrev = $app/abbrev]/version/string() },
                                attribute repo {$repo/url},
                                $app/@*,
                                $app/*,
                               <isData>{packages:is-data($app, $format)}</isData> 
                            }
                        else
                          ()
                        
                    else
                        $app
                }, $data/httpclient:body//app)
    } catch * {
        util:log("WARN", "Error while retrieving app packages: " || $err:description)
    }
};

declare %private function packages:is-newer($available as xs:string, $installed as xs:string) as xs:boolean {
    let $verInstalled := tokenize($installed, "\.")
    let $verAvailable := tokenize($available, "\.")
    return
        packages:compare-versions($verInstalled, $verAvailable)
};

declare %private function packages:compare-versions($installed as xs:string*, $available as xs:string*) as xs:boolean {
    if (empty($installed)) then
        exists($available)
    else if (empty($available)) then
        false()
    else if (head($available) = head($installed)) then
        packages:compare-versions(tail($installed), tail($available))
    else
        number(head($available)) > number(head($installed))
};