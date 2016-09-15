@{
    DependencyName = @{
        Name = 'Name'
        DependencyType = 'noop'
        Source = 'PWD=$PWD'
        Target = '.\Dependencies;$DependencyFolder'
    }
}