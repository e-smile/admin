xquery version "3.0";

import module namespace apputil="http://exist-db.org/xquery/apps";
(:import module namespace config="http://exist-db.org/xquery/apps/config" at "config.xqm";:)
import module namespace config="http://e-smile.org/es-admin/config" at "../config.xqm";

declare namespace install="http://exist-db.org/apps/dashboard/install";
declare namespace json="http://www.json.org";

declare option exist:serialize "method=json media-type=application/json";

declare %private function install:require-dba($func as function() as item()*) {
    if (xmldb:is-admin-user(xmldb:get-current-user())) then
        $func()
    else ( 
        response:set-status-code(403),
        <status><error>user {xmldb:get-current-user()} not authorized</error></status>
    )
};

let $action := request:get-parameter("action", "install")
let $package-url := request:get-parameter("package-url", ())
let $repo-url := request:get-parameter("repo-url", $config:DEFAULTREPO)
let $version := request:get-parameter("version", ())
let $server-url := $config:REPO
let $upload := request:get-uploaded-file-name("uploadedfiles[]")

(:let $log := util:log-system-out(("repo-url: ", $repo-url)):)
(:let $log := util:log-system-out(("url: ", $config:REPO)):)
return
    install:require-dba(
        function() {
        if (exists($upload)) then
            <result>
            {
                try {
                    let $docName := apputil:upload(xs:anyURI(($server-url[@default='true' or position() = 1]/url)[position() = 1]))
                    return
                        <json:value json:array="true">
                            <file>{$docName}</file>
                        </json:value>
                } catch * {
                    <json:value json:array="true">
                        <error>{$err:description}</error>
                    </json:value>
                }
            }
            </result>
        else
            switch ($action)
                case "remove" return
                    let $type := request:get-parameter("type", ())
                    let $removed := apputil:remove($package-url)
                    return
                        if ($removed) then
                            <status><ok>package removed !</ok></status>
                        else
                            <status><error>Failed to remove package {$package-url}</error></status>
                default return
                    (: Use dynamic lookup for backwards compatibility :)
                    let $func := function-lookup(xs:QName("apputil:install-from-repo"), 4)
                    return 
                        if($repo-url = $server-url/url)
                        then (
                            try {
                                if (empty($func)) then
                                    apputil:install-from-repo($package-url, (), $repo-url)
                                else
                                    $func($package-url, (), xs:anyURI ($repo-url), $version)
                            } catch * {
                                <status>
                                    <error>{$err:description}</error>
                                    <trace>{$exerr:xquery-stack-trace}</trace>
                                </status>
                            }
                        ) 
                        else    <status>
                                    <error>server-url not authorized</error>
                                </status>
    })