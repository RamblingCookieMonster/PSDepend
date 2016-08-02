PSDepend
========

This is a simple PowerShell dependency handler.  You might compare it to `bundle install` in the Ruby world or `pip install -r requirements.txt` in the Python world.

## *.Depend.psd1 - Your Dependencies

Store dependencies in a PowerShell data file, and use *.depend.psd1 to allow Invoke-PSDepend to find your files for you.

What does a dependency file look like?

### Simple syntax

Here's the simplest syntax:

```powershell
@{
    psake        = 'latest'
    Pester       = 'latest'
    BuildHelpers = '0.0.20'  # I don't trust this Warren guy...
    PSDeploy     = '0.1.21'  # Maybe pin the version in case he breaks this...
}
```

And what PSDepend sees:

```
DependencyName DependencyType  Version Tags
-------------- --------------  ------- ----
psake          PSGalleryModule latest      
BuildHelpers   PSGalleryModule 0.0.20      
Pester         PSGalleryModule             
PSDeploy       PSGalleryModule 0.1.21      
```

There's a bit more behind the scenes - we assume you want PSGalleryModule's unless you specify otherwise., and we hide a few dependency properties.

# Flexible syntax

What else can we put in a dependency?  Here's an example using a more flexible syntax.  You can mix and match.

```


```
