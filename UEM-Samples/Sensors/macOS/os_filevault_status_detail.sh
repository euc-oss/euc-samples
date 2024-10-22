#!/bin/bash
FDE_STATUS=$(fdesetup status)
ESCROW_PLIST="/var/db/ConfigurationProfiles/Settings/com.apple.security.FDERecoveryKeyEscrow.plist"
WS1_LOCATION="VMware AirWatch"
PRK_LOCATION="/var/db/FileVaultPRK.dat"
WS1_PRK_ISSUER="AwDiskEncryption"

/bin/echo -n "$FDE_STATUS "

if [ "FileVault is On." != "$FDE_STATUS" ]; then
    exit 0
fi

if [ -a "$ESCROW_PLIST" ]; then
    #verify key location is set correctly
    escrowLocation=$(defaults read "$ESCROW_PLIST" Location)
    if [ "$escrowLocation" = "$WS1_LOCATION" ]; then
        #verify key has been generated
        prkIssuer=$(/usr/bin/openssl cms -cmsout -in "$PRK_LOCATION" -inform DER -noout -print | /usr/bin/grep "issuer:")
        if [[ "$prkIssuer" = *"$WS1_PRK_ISSUER"* ]]; then
            #key is escrowed properly
            echo "Key Set to be Escrowed to: $(defaults read "$ESCROW_PLIST" Location)"
        else
            #key is not escrowed properly
            echo "KEY NOT ESCROWED"
        fi
    else
        #key is using wrong location - WS1 profile not installed
        echo "Key not set to escrow to WS1"
    fi
else
    # FDERecoveryKeyEscrow profile key is missing
    echo "FDERecoveryKeyEscrow Profile Not Installed"
fi

exit 0

# Description: Returns FileVault encryption status of device as well as FV recovery key status. 
# Execution Context: SYSTEM
# Execution Architecture: UNKNOWN
# Return Type: STRING
