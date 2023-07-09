<#
    We have a nested object, we would like a function that you pass in the object and a key and get back the value. How this is implemented is up to you.
    Example Inputs

#>
# Employe Nested Object 
$EmployNestedobject = @{
    PersonalInfo = @{
        FirstName = 'Ganesh'
        LastName = 'Vahinde'
    }
    Age = '31'
    DepartmentCode = 'XYZ'

}


Write-Output "Employ First Name: $($EmployNestedobject.PersonalInfo.FirstName)"
Write-Output "Employ Last Name: $($EmployNestedobject.PersonalInfo.LastName)"
Write-Output "Department Code: $($EmployNestedobject.DepartmentCode)"


