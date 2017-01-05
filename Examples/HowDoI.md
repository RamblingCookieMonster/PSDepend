# How Do I

Rather than scour the documentation, which may or may not be scenario focused, here is a quick list of common scenarios and recipes.

## Specify global defaults

You can use the special PSDependOptions node for default options:

```powershell
@{
    PSDependOptions = @{
        Target = 'C:\MyProject'
        DependencyType = 'PSGalleryNuget'
    }

    'PSDeploy' = 'latest'
    'BuildHelpers' = 'latest'
    'Pester' = 'latest'
    'InvokeBuild' = 'latest'
}
```

This downloads any dependency without an explicit override to `C:\MyProject`, using PSGalleryNuget

You can specify the following in PSDependOptions:

* Parameters
* Source
* Target
* AddToPath
* Tags
* DependsOn
* PreScripts
* PostScripts

## Specify global defaults, with overrides

You can override global defaults:

```powershell
@{
    PSDependOptions = @{
        Target = 'C:\MyProject'
        DependencyType = 'PSGalleryNuget'
    }

    'PSDeploy' = 'latest'
    'BuildHelpers' = 'latest'
    'Pester' = @{
        Target = 'C:\sc'
    }
    'InvokeBuild' = 'latest'
}
```

In this example, all modules are downloaded to `C:\MyProject`, apart from Pester, which has an override.

## Specify one target for all dependencies

You can certainly set a target on every single dependency, or:

```powershell
@{
    PSDependOptions = @{
        Target = 'C:\MyTarget'    # <<<<<<<
    }

    PSDeploy = 'latest'
    'darkoperator/ADAudit' = 'dev'
}
```

Just specify a target under PSDependOptions, this will be used as the default target unless you override it.

## Specify one target for most dependencies

If you want to specify one target for most dependencies, with a few exceptions:

```powershell
@{
    PSDependOptions = @{
        Target = 'C:\MyTarget'    # <<<<<<<
    }

    PSDeploy = 'latest'
    PSSlack = 'latest'
    PSJira = @{
        Target = 'C:\OtherTarget'
    }
    'darkoperator/ADAudit' = 'dev'
}
```



