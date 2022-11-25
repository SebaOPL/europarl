$MembersXML_URL = "https://www.europarl.europa.eu/meps/en/full-list/xml"
$VotingXML_URL = "https://www.europarl.europa.eu/doceo/document/PV-9-2022-11-23-RCV_FR.xml"

$EUParliamentMembers = [xml](Invoke-WebRequest -Uri $MembersXML_URL).Content
$EUParliamentMembers =  $EUParliamentMembers.meps.mep

$VotingDocument = [xml](Invoke-WebRequest -Uri $VotingXML_URL).Content

enum VoteToID {
    For = 1
    Against = 2
    Abstention = 3
}

Function GetEUParliamentMemberSessionVotingActionGrid([System.Xml.XmlElement[]]$ParliamentMembers, [System.Xml.XmlDocument]$VotingDoc)
{
    $EUParliamentMembersHash = @{}
    foreach($ParliamentMember in $ParliamentMembers)
    {
        $MemberData = @{}
        $MemberData.Add("Name",$ParliamentMember.fullName)
        $MemberData.Add("Country",$ParliamentMember.country)
        $MemberData.Add("PoliticalGroup",$ParliamentMember.politicalGroup)
        $MemberData.Add("NationalPoliticalGroup",$ParliamentMember.nationalPoliticalGroup)
        $MemberData.Add("Votings",@{})

        $EUParliamentMembersHash.Add("MepID:$($ParliamentMember.id)",$MemberData);
    }

    foreach($Voting in $VotingDocument.SelectNodes("/PV.RollCallVoteResults/RollCallVote.Result"))
    {
        foreach($Action in [VoteToID].GetEnumNames())
        {
            foreach($VotingAction in $voting.SelectNodes("Result.$($Action)/Result.PoliticalGroup.List/PoliticalGroup.Member.Name"))
            {
                $EUParliamentMembersHash["MepID:$($VotingAction.PersId)"]."Votings".Add("ID:$($Voting.Identifier)",[int][VoteToID]$Action)
            }
        }
    }

    $ResultMatrix = New-Object -TypeName System.Collections.Generic.List[psobject]
    foreach($ParliamentMember in $ParliamentMembers)
    {
        $ParliamentMemberVotings = New-Object -TypeName psobject -Property @{
            Name = $ParliamentMember.fullName
            Country = $ParliamentMember.Country
            PoliticalGroup = $ParliamentMember.politicalGroup
            NationalPoliticalGroup = $ParliamentMember.nationalPoliticalGroup
        }

        foreach($votingID in $VotingDocument.SelectNodes("/PV.RollCallVoteResults/RollCallVote.Result")|Foreach-Object{$_.Identifier})
        {
            $MemberVote = $EUParliamentMembersHash["MepID:$($ParliamentMember.id)"]."Votings"["ID:$($votingID)"]
            if(![string]::IsNullOrEmpty($MemberVote))
            {
                $ParliamentMemberVotings | Add-Member -MemberType NoteProperty -Name $votingID -Value $MemberVote
            }
            else {
                $ParliamentMemberVotings | Add-Member -MemberType NoteProperty -Name $votingID -Value 0
            }
        }
        $ResultMatrix.Add($ParliamentMemberVotings)
    }

    $ResultMatrix
}

$results = GetEUParliamentMemberSessionVotingActionGrid -ParliamentMembers $EUParliamentMembers -VotingDoc $VotingDocument

if(Test-Path .\output.csv){ Remove-Item .\output.csv }
$results | Export-Csv .\output.csv -NoClobber -NoTypeInformation -Encoding Unicode