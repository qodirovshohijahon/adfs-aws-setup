# $Age = Read-Host "Please enter your age"
 

# $Server = Read-Host -Prompt 'Input your server  name'
# $User = Read-Host -Prompt 'Input the user name'
# $Date = Get-Date
# Write-Host "You input server '$Servers' and '$User' on '$Date'"

# write content to txt file 
# $File = New-Object -TypeName System.IO.FileStream -ArgumentList "C:\Users\Administrator\Desktop\test.txt", [System.IO.FileMode]::Create
# $File.Write([System.Text.Encoding]::ASCII.GetBytes("Hello World!"), 0, 11)
# $File.Close()

#write function to write content to txt file with parameter 
function Write-To-File($file, $content) {
    $File = New-Object -TypeName System.IO.FileStream -ArgumentList $file, [System.IO.FileMode]::Create
    $File.Write([System.Text.Encoding]::ASCII.GetBytes($content), 0, $content.Length)
    $File.Close()
}
