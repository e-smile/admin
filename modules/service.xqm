xquery version "3.1";

(:module namespace service="http://exist-db.org/apps/dashboard/service";:)
module namespace service="http://e-smile.org/es-admin/service";

import module namespace sm = "http://exist-db.org/xquery/securitymanager";
(:import module namespace xqjson="http://xqilla.sourceforge.net/lib/xqjson";:)
(:import module namespace glc = "http://e-smile.org/common/config" at "../../common/modules/config.xqm";:)
import module namespace msg="http://e-smile.org/common/msg" at "../../common/modules/msg.xqm";
import module namespace e = "http://e-smile.org/common/errors" at "/db/apps/esmile/common/modules/errors.xqm";
import module namespace security = "http://e-smile.org/common/security" at "../../common/modules/security.xqm";

(:import module namespace jsjson = "http://johnsnelson/json" at "../userManager/jsjson.xqm";:)

declare namespace json="http://www.json.org";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace sen="http://www.sencha.com";
declare namespace err="http://www.w3.org/2005/xqt-errors/";

declare variable $service:ns := "http://e-smile.org/es-admin/service";
declare variable $service:NO_COLLECTION_RIGHT := QName($e:_403, 'noCollectionRight');
declare variable $service:NO_ACE := QName($e:_404, 'noAce');
declare variable $service:INVALID_PERMISSION := QName($e:_403, 'invalidPermission');

declare variable $service:map-message := map {
    'app' := 'admin'   
};

declare %private function service:map-msg($id, $lan) {
    map:new(($service:map-message,map:entry('version', 'latest'), map:entry('msg-id', $id), map:entry('lan', $lan)))  
};
  
(:~
 : msg:tryce Permissions  
 : --------------------
 :) 

declare
    %rest:GET
    %rest:path("/admin/{$appKey}/resources/{$id}")
    %rest:query-param("start", "{$start}","1")
    %rest:query-param("limit", "{$limit}", "1000000")
    %rest:query-param("lan","{$lan}","en")
    %rest:cookie-param("JSESSIONID", "{$session}", "_")
    %rest:header-param("token","{$token}","") 
    %rest:header-param("user","{$user}","guest") 
    %rest:header-param("password", "{$password}","")
    %output:media-type("application/json") 
    %output:method("json")
function service:resources($id, $start, $limit, $lan, $appKey, $user, $token,$session, $password) {
   
   let $fn := function() {
        let $login := security:login-attempt($user, $password,  $token, $session, $appKey)
        return 
            service:resources(xmldb:decode($id) , $start, $limit,$user)
    } 
    return msg:try($fn)   
}; 


declare
    %rest:PUT("{$data}") 
    %rest:path("/admin/{$appKey}/resources/{$id}")
    %rest:query-param("lan","{$lan}","en")
    %rest:cookie-param("JSESSIONID", "{$session}", "_")
    %rest:header-param("token","{$token}","") 
    %rest:header-param("user","{$user}","guest") 
    %rest:header-param("password", "{$password}","")
    %output:media-type("application/json") 
    %output:method("json")
    %msg:success("resourceModified","resource succesfully modified")
    %msg:error("resourceNotModified", "could not modify resource")
function service:resources-update($data, $id, $lan,$appKey, $user, $token,$session, $password) {
    
   let $fn := function() {
       let $login := security:login-attempt($user, $password,  $token, $session, $appKey)
       return service:resources-update($data, xmldb:decode($id) )  
   } 
    return 
        msg:try($fn, service:map-msg("service:resources-update", $lan))   
};

(:declare:)
(:    %rest:DELETE:)
(:    %rest:path("/admin/{$appKey}/contents"):)
(:    %rest:form-param("collection", "{$collection}"):)
(:    %rest:cookie-param("JSESSIONID", "{$session}", "_"):)
(:    %rest:header-param("token","{$token}","") :)
(:    %rest:header-param("user","{$user}","guest") :)
(:    %rest:header-param("password", "{$password}",""):)
(:    %output:media-type("application/json"):)
(:    %output:method("json"):)
(:    %msg:success("resourceDeleted","the resource has succesfully deleted"):)
(:    %msg:error("resourceNotDeleted", "the resource could not be deleted"):)
(:function service:delete-resources($collection as xs:string*,$appKey, $user, $token,$session, $password)  {:)
(:    let $fn := function() {:)
(:        let $login := security:login-attempt($user, $password,  $token, $session, $appKey):)
(:        return ( :)
(:            for $resource in $collection:)
(:        return:)
(:            if (xmldb:collection-available($resource)) then:)
(:                xmldb:remove($resource):)
(:            else:)
(:                let $split := analyze-string($resource, "^(.*)/([^/]+)$")//fn:group/string():)
(:                return:)
(:                    xmldb:remove($split[1], $split[2]),:)
(:        <response status="ok"/>):)
(:    } :)
(:    return msg:try($fn)       :)
(:};
 : :) 


declare  %private function service:resources($id as xs:string*, $start, $limit,$user) {
   
        let $start := number($start)
        let $limit := number($limit)
        let $resources := service:list-collection-contents($id, $user)
        let $subset := subsequence($resources, $start, $limit - $start + 1)
     
        return (
                for $resource in $subset
                let $is-collection := local-name($resource) eq "collection"
                let $path := string-join(($id, $resource), "/")
                return
                    service:resource-xml($path, (), $is-collection, $user)
        )
};


declare
    %private
function service:resource-xml($path as xs:string, $name as xs:string?, $is-collection as xs:boolean, $user as xs:string) as element(json:value) {
    let $permission := sm:get-permissions(xs:anyURI($path))/sm:permission,
    $collection := replace($path, "(.*)/.*", "$1"),
    $resource := replace($path, ".*/(.*)", "$1"),
    $created := if($is-collection) then  xmldb:created($path) else xmldb:created($collection, $resource),
    $last-modified := if($is-collection) then $created else xmldb:last-modified($collection, $resource),
    $internet-media-type :=
        if($is-collection) then
            "<Collection>"
        else
            xmldb:get-mime-type(xs:anyURI($path))
        ,
    $can-write :=
        if($is-collection) then
            service:canWrite($path, $user)
        else
            service:canWriteResource($collection, $resource, $user)
        ,
    $mime := if($is-collection) then () else <mime>{xmldb:get-mime-type(xs:anyURI($path))}</mime>
    
    return
        <json:value json:array="true">
            <name>{if($name)then $name else replace($path, ".*/(.*)", "$1")}</name>
            <id>{$path}</id>
            <permissions>{if($is-collection)then "c" else "-"}{string($permission/@mode)}{if($permission/sm:acl/@entries ne "0")then "+" else ""}</permissions>
            <ownerId>{string($permission/@owner)}</ownerId>
            <groupId>{string($permission/@group)}</groupId>
            <internetMediaType>{$internet-media-type}</internetMediaType>
            {$mime}
            <created>{$created}</created>
            <lastModified>{$last-modified}</lastModified>
            <writable json:literal="true">{$can-write}</writable>
            <isCollection json:literal="true">{$is-collection}</isCollection>
            <acls>{service:resources-acl($path)}</acls>
        </json:value>
};
 
declare %private function service:resources-update($data, $id) {
(:    let $data := xqjson:parse-json(util:base64-decode($data)):)
(:    let $log := util:log-system-out($data):)
 
(:    let $owner :=  $data//pair[@name="owner"],:)
(:        $group :=  $data//pair[@name="group"],:)
(:        $permission := $data//pair[@name="permission"],:)
(:        $mime :=   $data//pair[@name="mime"]:)
    let $data := parse-json(util:base64-decode($data))   
    let $owner :=  $data?owner,
        $group :=  $data?group,
        $permission := $data?permission,
        $mime :=   $data?mime
        
    let $permission := if(ends-with($permission, "+")) then (substring-before($permission, "+")) else $permission 
        
    let $process := function($arg, $fn) {
        if($arg) then $fn($id, $arg) else ()
    }    
    return  
    (
        $process($owner, sm:chown#2),
        $process($group, sm:chgrp#2),
        $process($permission, sm:chmod#2),
        $process($mime, xmldb:set-mime-type#2)
    )    

};
 

(:~
 : Resource ACL
 : ------------
 :)


declare 
    %rest:GET
    %rest:path("/admin/{$appKey}/resources-acl/{$path}")
    %rest:query-param("lan","{$lan}","en")
    %rest:cookie-param("JSESSIONID", "{$session}", "_")
    %rest:header-param("token","{$token}","") 
    %rest:header-param("user","{$user}","guest") 
    %rest:header-param("password", "{$password}","")
    %output:media-type("application/json") 
    %output:method("json")
function service:resources-acl($path ,$lan, $appKey, $user, $token,$session, $password) {
   let $fn := function() {
        let $login := security:login-attempt($user, $password,  $token, $session, $appKey)
        return service:resources-acl(xmldb:decode($path))  
   } 
    return 
        msg:try($fn)   
};

declare
    %rest:POST("{$data}") 
    %rest:path("/admin/{$appKey}/resources-acl/{$path}")
    %rest:query-param("lan","{$lan}","en")
    %rest:cookie-param("JSESSIONID", "{$session}", "_")
    %rest:header-param("token","{$token}","") 
    %rest:header-param("user","{$user}","guest") 
    %rest:header-param("password", "{$password}","")
    %output:media-type("application/json") 
    %output:method("json")
    %msg:success("aclCreated","acl succesfully created")
    %msg:error("aclNotCreated", "could not create acl")
function service:resources-acl-create($data, $path, $index, $lan,$appKey, $user, $token,$session, $password) {
   
   let $fn := function() {
        let $login := security:login-attempt($user, $password,  $token, $session, $appKey)
        return service:resources-acl-create(xmldb:decode($path), $data)  
   } 
   return 
        msg:try($fn, service:map-msg("service:resources-acl-create", $lan))   
};


declare
    %rest:PUT("{$data}") 
    %rest:path("/admin/{$appKey}/resources-acl/{$path}/{$index}")
    %rest:query-param("lan","{$lan}","en")
    %rest:cookie-param("JSESSIONID", "{$session}", "_")
    %rest:header-param("token","{$token}","") 
    %rest:header-param("user","{$user}","guest") 
    %rest:header-param("password", "{$password}","")
    %output:media-type("application/json") 
    %output:method("json")
    %msg:success("aclModified","acl succesfully modified")
    %msg:error("aclNotModified", "could not modify acl")
function service:resources-acl-update($data, $path, $index, $lan,$appKey, $user, $token,$session, $password) {
    
   let $fn := function() {
       let $login := security:login-attempt($user, $password,  $token, $session, $appKey)
       return service:resources-acl-update(xmldb:decode($path), $index, $data)  
   } 
    return 
        msg:try($fn, service:map-msg("service:resources-acl-update", $lan))   
};

declare
    %rest:DELETE
    %rest:path("/admin/{$appKey}/resources-acl/{$path}/{$index}")
    %rest:query-param("lan","{$lan}","en")
    %rest:cookie-param("JSESSIONID", "{$session}", "_")
    %rest:header-param("token","{$token}","") 
    %rest:header-param("user","{$user}","guest") 
    %rest:header-param("password", "{$password}","")
    %output:media-type("application/json") 
    %output:method("json")
    %msg:success("aclDeleted","acl succesfully deleted")
    %msg:error("aclNotDeleted", "could not delete acl")
function service:resources-acl-delete($path, $index,$lan, $appKey, $user, $token,$session, $password) {
   
   let $fn := function() {
        let $login := security:login-attempt($user, $password,  $token, $session, $appKey)
        for $p in $path return service:resources-acl-delete(xmldb:decode($path),xs:integer($index))  
   } 
    return 
        msg:try($fn, service:map-msg("service:resources-acl-delete", $lan))   
};

declare %private function service:ace($path as xs:string, $ace) { 
    <json:value json:array="true">{
        $ace/@*}
        <id>{$path || '_' || $ace/@index}</id>
        <path>{$path}</path>
    </json:value>
};

declare %private function service:resources-acl($path as xs:string) {
    for $ace in sm:get-permissions(xs:anyURI($path))//sm:ace
     return 
        service:ace($path, $ace)
     
};

declare %private function service:resources-acl-delete($path as xs:string, $index as xs:integer) {
    sm:remove-ace($path, $index)
        
};

declare %private function  service:resources-acl-create( $path, $data) {
(:     let $data := xqjson:parse-json(util:base64-decode($data)),:)
(:        $target := $data//pair[@name="target"],:)
(:        $type := ($data//pair[@name="access_type"] = 'ALLOWED'),:)
(:        $who := $data//pair[@name="who"],:)
(:        $mode := $data//pair[@name="mode"]:)
    
    let $data := parse-json(util:base64-decode($data))   
    let $target := $data?target,
        $type :=($data?access_type = 'ALLOWED'),
        $who := $data?who,
        $mode := $data?mode
    
     let $add := if($target = "GROUP") 
                then sm:add-group-ace($path, $who, $type, $mode) 
                else sm:add-user-ace($path, $who, $type, $mode)
    let $last := sm:get-permissions(xs:anyURI($path))//sm:ace[last()]
    return   
        service:ace($path, $last)
         
}; 

declare %private function service:resources-acl-update($path as xs:string, $index as xs:string, $data) {
    let $ace := sm:get-permissions(xs:anyURI($path))//sm:ace[@index = $index]
(:    let $data := xqjson:parse-json(util:base64-decode($data)):)
    let $data := parse-json(util:base64-decode($data))   
(:    let $log := util:log-system-out($data):)
(:    let $error :=  error($service:NO_ACE, "Access Control List empty for  " || $path || " " || $index):)
    return 
        if(empty($ace)) 
        then  (
             error($service:NO_ACE, "Access Control List empty for  " || $path || " " || $index)
            )
        else (
            let $index := xs:integer($index),
                $target := $data?target,
                $type :=($data?access_type = 'ALLOWED'),
                $who := $data?who,
                $mode := $data?mode
(:             $target := $data//pair[@name="target"],:)
(:             $type := ($data//pair[@name="access_type"] = 'ALLOWED'),:)
(:             $who := $data//pair[@name="who"],:)
(:             $mode := $data//pair[@name="mode"] :)
            
            let $add := if($target = "GROUP") 
                then sm:insert-group-ace($path,$index , $who, $type, $mode) 
                else sm:insert-user-ace($path, $index, $who, $type, $mode)
            
            let $remove := sm:remove-ace($path, $index + 1)
            return 
                service:ace($path, sm:get-permissions(xs:anyURI($path))//sm:ace[@index = $index])
            )
            

};
 


(:declare:)
(:    %rest:POST:)
(:    %rest:path("/admin/{$appKey}/contents/{$target}"):)
(:    %rest:form-param("action", "{$action}", "copy"):)
(:    %rest:form-param("collection", "{$collection}"):)
(:    %rest:cookie-param("JSESSIONID", "{$session}", "_"):)
(:    %rest:header-param("token","{$token}","") :)
(:    %rest:header-param("user","{$user}","guest") :)
(:    %rest:header-param("password", "{$password}",""):)
(:    %output:media-type("application/json"):)
(:    %output:method("json"):)
(:function service:copyOrMove($target as xs:string, $collection as xs:string*, $action as xs:string*,$appKey, $user, $token,$session, $password)  {:)
(:    let $fn := function() {:)
(:        let $login := security:login-attempt($user, $password,  $token, $session, $appKey):)
(:        let $user := xmldb:get-current-user():)
(:        let $target := concat("/", $target) :)
(:(:    let $user := if (request:get-attribute('org.exist.login.user')) then request:get-attribute('org.exist.login.user') else "guest":):)
(:        return:)
(:        if ($action = "reindex") then:)
(:            let $reindex := xmldb:reindex($target):)
(:            return:)
(:                <response status="ok"/>:)
(:        else:)
(:            if (service:canWrite($target, $user)) then ( :)
(:                for $source in $collection:)
(:                let $isCollection := xmldb:collection-available($source):)
(:                return:)
(:                    if ($isCollection) then:)
(:                        switch($action):)
(:                            case "move" return:)
(:                                xmldb:move($source, $target):)
(:                            default return:)
(:                                xmldb:copy($source, $target):)
(:                    else:)
(:                        let $split := analyze-string($source, "^(.*)/([^/]+)$")//fn:group/string():)
(:                        return:)
(:                            switch ($action):)
(:                                case "move" return:)
(:                                    xmldb:move($split[1], $target, $split[2]):)
(:                                default return:)
(:                                    xmldb:copy($split[1], $target, $split[2]),:)
(:                    <response status="ok"/>:)
(:            ) else :)
(:                 error($service:NO_COLLECTION_RIGHT, "You are not allowed to write to collection " || $target):)
(:(:                <response status="fail">:):)
(:(:                    <message>You are not allowed to write to collection {$target}.</message>:):)
(:(:                </response>:):)
(:    }:)
(:     return glc:try($fn):)
(:};:)
(::)
(:declare:)
(:    %rest:PUT:)
(:    %rest:path("/admin/{$appKey}/contents/{$target}"):)
(:    %rest:query-param("collection", "{$collection}"):)
(:     %rest:cookie-param("JSESSIONID", "{$session}", "_"):)
(:    %rest:header-param("token","{$token}","") :)
(:    %rest:header-param("user","{$user}","guest") :)
(:    %rest:header-param("password", "{$password}",""):)
(:    %output:media-type("application/json"):)
(:    %output:method("json"):)
(:function service:create-collection($collection as xs:string*, $target as xs:string,$appKey, $user, $token,$session, $password)  {:)
(:(:    let $user := if (request:get-attribute('org.exist.login.user')) then request:get-attribute('org.exist.login.user') else "guest":):)
(:(:    let $log := util:log("DEBUG", ("creating collection ", $collection)):):)
(: let $fn := function() {:)
(:        let $login := security:login-attempt($user, $password,  $token, $session, $appKey):)
(:        let $user := xmldb:get-current-user() :)
(:        return:)
(:            if (service:canWrite($collection, $user)) then:)
(:                (xmldb:create-collection($collection, $target), <response status="ok"/>)[2]:)
(:            else :)
(:                error($service:NO_COLLECTION_RIGHT, "You are not allowed to write to collection " || $collection):)
(:(:            <response status="fail">:):)
(:(:                <message>You are not allowed to write to collection {$collection}.</message>:):)
(:(:            </response>:):)
(:  }:)
(:   return glc:try($fn):)
(:};:)

(:declare:)
(:    %rest:GET:)
(:    %rest:path("/admin/{$appKey}/permissions/{$id}/{$class}"):)
(:    %rest:cookie-param("JSESSIONID", "{$session}", "_"):)
(:    %rest:header-param("token","{$token}","") :)
(:    %rest:header-param("user","{$user}","guest") :)
(:    %rest:header-param("password", "{$password}",""):)
(:    %output:media-type("application/json"):)
(:    %output:method("json"):)
(:function service:get-permissions($id as xs:string, $class as xs:string,$appKey, $user, $token,$session, $password) as element(json:value) {:)
(:    let $fn := function() {:)
(:        let $login := security:login-attempt($user, $password,  $token, $session, $appKey):)
(:        let $path := service:id-to-path($id),:)
(:        $permissions := sm:get-permissions(xs:anyURI($path))/sm:permission:)
(:        return:)
(:           <json:value>:)
(:            { :)
(:                for $c in service:permissions-classes-xml($permissions)[if(string-length($class) eq 0)then true() else id = $class] return:)
(:                    <json:value json:array="true">{:)
(:                        $c/child::element():)
(:                    }</json:value>:)
(:            }:)
(:            </json:value>:)
(:    }:)
(:   return glc:try($fn):)
(:};:)

declare
    %rest:PUT("{$data}")
    %rest:path("/admin/{$appKey}/permissions/{$id}")
    %rest:cookie-param("JSESSIONID", "{$session}", "_")
    %rest:header-param("token","{$token}","") 
    %rest:header-param("user","{$user}","guest") 
    %rest:header-param("password", "{$password}","")
    %output:media-type("application/json")
    %output:method("json")
function service:save-permissions($data, $id as xs:string,$appKey, $user, $token,$session, $password) {
        let $fn := function() {
        let $login := security:login-attempt($user, $password,  $token, $session, $appKey)
    
    let $log := util:log-system-out(('DATA: ', $data))
(:    let $recv-permissions := xqjson:parse-json(util:base64-decode($data)),:)
    let $recv-permissions := parse-json(util:base64-decode($data)),
        $path := service:id-to-path($id)
    return
    
(:        let $cs :=:)
(:            if($recv-permissions/pair[@name eq "id"] eq "User") then:)
(:                ("u", if($recv-permissions/pair[@name eq "special"] eq "true") then "+s" else "-s"):)
(:            else if($recv-permissions/pair[@name eq "id"] eq "Group") then:)
(:                ("g", if($recv-permissions/pair[@name eq "special"] eq "true") then "+s" else "-s"):)
(:            else if($recv-permissions/pair[@name eq "id"] eq "Other") then:)
(:                ("o", if($recv-permissions/pair[@name eq "special"] eq "true") then "+t" else "-t"):)
(:            else(),:)
        let $cs :=
            if($recv-permissions?id eq "User") then
                ("u", if($recv-permissions?special eq "true") then "+s" else "-s")
            else if($recv-permissions?id eq "Group") then
                ("g", if($recv-permissions?special eq "true") then "+s" else "-s")
            else if($recv-permissions?id eq "Other") then
                ("o", if($recv-permissions?special eq "true") then "+t" else "-t")
            else(),

            
        $c := $cs[1], (: received class :)
        $s := $cs[2], (: received special :)
            
        $r := 
            concat(if($recv-permissions/pair[@name eq "read"] eq "true") then
                "+"
            else 
                "-"
            ,"r"),
        
        $w :=
            concat(if($recv-permissions/pair[@name eq "write"] eq "true") then
                "+"
            else 
                "-"
            ,"w"),
            
        $x :=
            concat(if($recv-permissions/pair[@name eq "execute"] eq "true") then
                "+"
            else 
                "-"
            ,"x")
            
        return
            if(not(empty($cs))) then
            (
                sm:chmod(xs:anyURI($path), $c || $r || "," || $c || $w || "," || $c || $x || "," || $c || $s),
                <response status="ok"/>
            )
            else
                  error($service:INVALID_PERMISSION, "Invalid class to set permissons for!")
(:                <response status="fail">:)
(:                    <message>Invalid class to set permissons for!</message>:)
(:                </response>:)
        }
        return msg:try($fn)
};

(:declare:)
(:    %rest:GET:)
(:    %rest:path("/admin/{$appKey}/acl/{$id}/{$acl-id}"):)
(:    %rest:cookie-param("JSESSIONID", "{$session}", "_"):)
(:    %rest:header-param("token","{$token}","") :)
(:    %rest:header-param("user","{$user}","guest") :)
(:    %rest:header-param("password", "{$password}",""):)
(:    %output:media-type("application/json"):)
(:    %output:method("json"):)
(:function service:get-acl($id as xs:string, $acl-id as xs:string,$appKey, $user, $token,$session, $password) as element(json:value) {:)
(:    let $fn := function() {:)
(:        let $login := security:login-attempt($user, $password,  $token, $session, $appKey):)
(:        let $path := service:id-to-path($id),:)
(:        $permissions := sm:get-permissions(xs:anyURI($path))/sm:permission:)
(:        return:)
(:           <json:value>:)
(:            { :)
(:                for $ace in $permissions/sm:acl/sm:ace[if(string-length($acl-id) eq 0)then true() else @index eq $acl-id] return:)
(:                    <json:value json:array="true">:)
(:                        <id>{$ace/string(@index)}</id>:)
(:                        <target>{$ace/string(@target)}</target>:)
(:                        <who>{$ace/string(@who)}</who>:)
(:                        <access_type>{$ace/string(@access_type)}</access_type>:)
(:                        <read json:literal="true">{$ace/contains(@mode, "r")}</read>:)
(:                        <write json:literal="true">{$ace/contains(@mode, "w")}</write>:)
(:                        <execute json:literal="true">{$ace/contains(@mode, "x")}</execute>:)
(:                    </json:value>:)
(:            }:)
(:            </json:value>:)
(:    }:)
(:      return glc:try($fn):)
(:};:)
(::)
declare
    %private
function service:id-to-path($id as xs:string) as xs:string {
    replace($id, "\.\.\.", "/")
};

declare
    %rest:POST("{$data}")
    %rest:path("/admin/{$appKey}/properties")
    %rest:form-param("owner", "{$owner}")
    %rest:form-param("group", "{$group}")
    %rest:form-param("resources", "{$resources}")
    %rest:form-param("mime", "{$mime}")
    %rest:cookie-param("JSESSIONID", "{$session}", "_")
    %rest:header-param("token","{$token}","") 
    %rest:header-param("user","{$user}","guest") 
    %rest:header-param("password", "{$password}","")
    %output:media-type("application/json")
    %output:method("json")
function service:change-properties($data, $resources as xs:string*, $owner as xs:string*, $group as xs:string*, $mime as xs:string*,$appKey, $user, $token,$session, $password) {
     let $fn := function() {
        let $login := security:login-attempt($user, $password,  $token, $session, $appKey)
            for $resource in $resources
            let $uri := xs:anyURI($resource)
            let $log := util:log-system-out(('DATA: ', $data))
            return (
                sm:chown($uri, $owner),
                sm:chgrp($uri, $group),
                sm:chmod($uri, service:permissions-from-form()),
                xmldb:set-mime-type($resource, $mime)
            ),
            <response status="ok"/>
     }
      return msg:try($fn)        
};

(:declare:)
(:    %rest:POST:)
(:    %rest:path("/upload/"):)
(:    %output:media-type("application/json"):)
(:    %output:method("json"):)
(:function service:upload() {:)
(:    let $collection := request:get-parameter("collection", "/db/abc"):)
(:    let $names := request:get-uploaded-file-name("uploadedfiles[]"):)
(:    let $files := request:get-uploaded-file-data("uploadedfiles[]"):)
(:    let $log := util:log("DEBUG", ("files: ", $files)):)
(:    return:)
(:        <result>:)
(:        {:)
(:            map-pairs(function($name, $file) {:)
(:                let $stored := xmldb:store($collection, xmldb:encode-uri($name), $file):)
(:                let $log := util:log("DEBUG", ("Uploaded: ", $stored)):)
(:                return:)
(:                    <json:value>:)
(:                        <file>{$stored}</file>:)
(:                        <size>xmldb:size($collection, $name)</size>:)
(:                        <type>xmldb:get-mime-type($stored)</type>:)
(:                    </json:value>:)
(:            }, $names, $files):)
(:        }:)
(:        </result>:)
(:};:)

declare %private function service:permissions-from-form() {
    string-join(
        for $type in ("u", "g", "w")
        for $perm in ("r", "w", "x")
        let $param := request:get-parameter($type || $perm, ())
        return
            if ($param) then
                $perm
            else
                "-",
        ""
    )
};

declare %private function service:list-collection-contents($collection as xs:string, $user as xs:string) {
    
    (
        for $child in xmldb:get-child-collections($collection)
        order by $child ascending
        return
            <collection>{$child}</collection>
        ,
        for $resource in xmldb:get-child-resources($collection)
        order by $resource ascending
        return
            <resource>{$resource}</resource>
    )
    
    (:
    let $subcollections := 
        for $child in xmldb:get-child-collections($collection)
        where sm:has-access(xs:anyURI(concat($collection, "/", $child)), "r")
        return
            $child
    let $resources :=
        for $r in xmldb:get-child-resources($collection)
        where sm:has-access(xs:anyURI(concat($collection, "/", $r)), "r")
        return
            $r
    for $resource in ($subcollections, $resources)
    order by $resource ascending
	return
		$resource
	:)
};

declare %private function service:canWrite($collection as xs:string, $user as xs:string) as xs:boolean {
    if (xmldb:is-admin-user($user)) then
    	true()
	else
    	let $permissions := xmldb:permissions-to-string(xmldb:get-permissions($collection))
    	let $owner := xmldb:get-owner($collection)
    	let $group := xmldb:get-group($collection)
    	let $groups := xmldb:get-user-groups($user)
    	return
        	if ($owner eq $user) then
            	substring($permissions, 2, 1) eq 'w'
        	else if ($group = $groups) then
            	substring($permissions, 5, 1) eq 'w'
        	else
            	substring($permissions, 8, 1) eq 'w'
};

declare %private function service:canWriteResource($collection as xs:string, $resource as xs:string, $user as xs:string) as xs:boolean {
    if (xmldb:is-admin-user($user)) then
		true()
	else
		let $permissions := xmldb:permissions-to-string(xmldb:get-permissions($collection, $resource))
		let $owner := xmldb:get-owner($collection, $resource)
		let $group := xmldb:get-group($collection, $resource)
		let $groups := xmldb:get-user-groups($user)
		return
			if ($owner eq $user) then
				substring($permissions, 2, 1) eq 'w'
			else if ($group = $groups) then
				substring($permissions, 5, 1) eq 'w'
			else
				substring($permissions, 8, 1) eq 'w'
};

declare %private function service:merge-properties($maps as map(*)) {
    map:new(
        for $key in map:keys($maps[1])
        let $values := distinct-values(for $map in $maps return $map($key))
        return
            map:entry($key, if (count($values) = 1) then $values[1] else "")
    )
};

declare %private function service:get-property-map($resource as xs:string) as map(*) {
    let $isCollection := xmldb:collection-available($resource)
    return
        if ($isCollection) then
            map {
                "owner" := xmldb:get-owner($resource),
                "group" := xmldb:get-group($resource),
                "last-modified" := format-dateTime(xmldb:created($resource), "[MNn] [D00] [Y0000] [H00]:[m00]:[s00]"),
                "permissions" := xmldb:permissions-to-string(xmldb:get-permissions($resource)),
                "mime" := xmldb:get-mime-type(xs:anyURI($resource))
            }
        else
            let $components := analyze-string($resource, "^(.*)/([^/]+)$")//fn:group/string()
            return
                map {
                    "owner" := xmldb:get-owner($components[1], $components[2]),
                    "group" := xmldb:get-group($components[1], $components[2]),
                    "last-modified" := 
                        format-dateTime(xmldb:last-modified($components[1], $components[2]), "[MNn] [D00] [Y0000] [H00]:[m00]:[s00]"),
                    "permissions" := xmldb:permissions-to-string(xmldb:get-permissions($components[1], $components[2])),
                    "mime" := xmldb:get-mime-type(xs:anyURI($resource))
                }
};

declare %private function service:get-properties($resources as xs:string*) as map(*) {
    service:merge-properties(for $resource in $resources return service:get-property-map($resource))
};

declare %private function service:get-users() {
    distinct-values(
        for $group in sm:get-groups()
        return
            sm:get-group-members($group)    
    )
};

declare
    %private
function service:checkbox($name as xs:string, $test as xs:boolean) {
    <input type="checkbox" name="{$name}"
        data-dojo-type="dijit.form.CheckBox">
    {
        if ($test) then attribute checked { 'checked' } else ()
    }
    </input>
};

declare %private function service:force-json-array($nodes as node()*, $element-names as xs:QName+) {
   for $node in $nodes
   return 
      typeswitch($node)
        case document-node()
        return
            document {
                for $child in $node
                return
                    service:force-json-array($child/node(), $element-names)
            }
        case element()
        return
              element { name($node) } {
                if(node-name($node) = $element-names)then
                    attribute json:array { "true" }
                else(),
 
                for $att in $node/@*
                return
                    attribute {name($att)} {$att}
                ,
                for $child in $node
                return
                    service:force-json-array($child/node(), $element-names)
              }
        default
        return
            $node
};

declare %private function service:path-to-col-res-path($path as xs:string) {
    (replace($path, "(.*)/.*", "$1"), replace($path, ".*/", ""))
};