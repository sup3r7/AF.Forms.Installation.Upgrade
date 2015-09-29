Function Open-TextFile {
    [CmdletBinding()]
    Param()
    DynamicParam {
        $attributes = new-object System.Management.Automation.ParameterAttribute
        $attributes.ParameterSetName = "__AllParameterSets"
        $attributes.Mandatory = $true
         
        $attributeCollection = new-object -Type System.Collections.ObjectModel.Collection[System.Attribute]
        $attributeCollection.Add($attributes)
         
        $folder = 'C:\temp'
        $_Values = (Get-ChildItem -Path $folder -Name *.txt).PSChildName
                 
        $ValidateSet = new-object System.Management.Automation.ValidateSetAttribute($_Values)
                 
        $attributeCollection.Add($ValidateSet)
         
         
        $dynParam1 = new-object -Type System.Management.Automation.RuntimeDefinedParameter("File", [string], $attributeCollection)
         
        $paramDictionary = new-object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
        $paramDictionary.Add("File", $dynParam1)
        return $paramDictionary
    }
 
    Process 
    {
        $file = $PSBoundParameters.file
        ise "$folder\$file"
    }
}