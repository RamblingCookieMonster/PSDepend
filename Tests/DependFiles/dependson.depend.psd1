@{    
    two = @{
        DependencyType = 'noop'
        DependsOn = 'one'
    }

    three= @{
        DependencyType = 'noop'
        DependsOn = 'two'
    }
    
    one = @{
        DependencyType = 'noop'
    }
}