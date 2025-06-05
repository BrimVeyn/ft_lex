%%
[a-z]{5,100}[0-9]{2,5}(abc|def|ghi)?                  { return WEIRD_ID; }
(([A-Z]+[a-z]+)+_)+                                  { return CAMEL_CASE_UNDERSCORE; }
[^aeiou]{3,5}([aeiou]{2})[^aeiou]{3,5}               { return PATTERNED; }
([0-9]{2}-){2}[0-9]{4}                               { return DATE_DASH; }
[a-z]{2,4}(\.[a-z]{2,3}){1,3}                        { return DOMAIN_NAME; }
[ \t\r\n]+                                           { /* skip whitespace */ }
.                                                    { return UNKNOWN; }
