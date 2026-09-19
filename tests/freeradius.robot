*** Settings ***
Library    SSHLibrary

*** Variables ***
${SECRET}     robot-test-secret-0123456789
${CONFIG}     {"host":"radius.ns8.test","http2https":true,"lets_encrypt":false,"ldap_domain":"","clients":[{"name":"robot","ipaddr":"0.0.0.0/0","secret":"${SECRET}"}]}

*** Keywords ***
Radtest
    [Arguments]    ${user}    ${password}
    # rootless container on the host network, reuses the image the module already pulled
    ${out}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'podman run --rm --network\=host --entrypoint radtest $FREERADIUS_SERVER_IMAGE -t pap ${user} ${password} 127.0.0.1 0 ${SECRET} 2>&1'
    ...    return_rc=True
    [Return]    ${out}

Units are active
    ${out} =    Execute Command    runagent -m ${module_id} systemctl --user is-active freeradius.service freeradius-app.service | sort -u
    Should Be Equal As Strings    ${out}    active

Login is accepted
    ${out} =    Radtest    robot    robot-pass-1
    Should Contain    ${out}    Access-Accept

*** Test Cases ***
Check if freeradius is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Suite Variable    ${module_id}    ${output.module_id}

Check if freeradius can be configured
    ${rc} =    Execute Command    api-cli run module/${module_id}/configure-module --data '${CONFIG}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if the units are active
    Wait Until Keyword Succeeds    12 times    5 seconds    Units are active

Check if the shared secret stays out of the environment
    ${out} =    Execute Command    grep -c '${SECRET}' /home/${module_id}/.config/state/environment ; redis-cli --raw HVALS module/${module_id}/environment | grep -c '${SECRET}'
    Should Be Equal As Strings    ${out}    0\n0
    ${mode} =    Execute Command    stat -c \%a /home/${module_id}/.config/state/clients.json
    Should Be Equal As Strings    ${mode}    600

Check if the server does not use the test certificate of the image
    ${issuer} =    Execute Command    openssl x509 -in /home/${module_id}/.config/state/certs/server.pem -noout -issuer
    Should Not Contain    ${issuer}    Example

Check if a local user can log in
    Execute Command    runagent -m ${module_id} bash -c 'printf "robot\\tCleartext-Password := \\"robot-pass-1\\"\\n" >> config/authorize && systemctl --user restart freeradius-app.service'
    Wait Until Keyword Succeeds    12 times    5 seconds    Units are active
    ${out} =    Wait Until Keyword Succeeds    6 times    5 seconds    Login is accepted
    ${out} =    Radtest    robot    wrong-password
    Should Contain    ${out}    Access-Reject

Check if the configuration reads back
    ${out} =    Execute Command    api-cli run module/${module_id}/get-configuration
    ${cfg} =    Evaluate    json.loads('''${out}''')    modules=json
    Should Be Equal    ${cfg['host']}    radius.ns8.test
    Should Be Equal    ${cfg['clients'][0]['name']}    robot
    Should Be Equal    ${cfg['ldap_domain']}    ${EMPTY}

Check if freeradius is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
