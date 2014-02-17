define windows_common::configuration::service (
  $ensure       = present,
  $binpath,
  $display      = $name,
  $description  = "",
  $user         = "LocalSystem",
  $password     = "",
){
  Exec { provider => powershell }

  case $ensure {
    present: {
      exec { "create-windows-service-${name}":
        command => "& sc.exe create ${name} binpath= \" ${binpath} \" start= auto DisplayName= \"${display}\" ",
        unless  => "exit @(Get-Service ${name}).Count -eq 0",
      }

      registry_value { "HKLM\\System\\CurrentControlSet\\Services\\${name}\\ImagePath":
        ensure  => present,
        type    => expand,
        data    => $binpath,
        require => Exec["create-windows-service-${name}"],
      }

      registry_value { "HKLM\\System\\CurrentControlSet\\Services\\${name}\\DisplayName":
        ensure => present,
        type   => string,
        data   => $display,
        require => Exec["create-windows-service-${name}"],
      }

      registry_value { "HKLM\\System\\CurrentControlSet\\Services\\${name}\\Description":
        ensure => present,
        type   => string,
        data   => $description,
        require => Exec["create-windows-service-${name}"],
      }

      exec { "ensure-${name}-logon-rights":
        command     => template('windows_common/configuration/logon-as-service.ps1.erb'),
        refreshonly => true,
      }

      exec { "ensure-${name}-service-credentials":
        command => "& sc.exe config ${name} obj= ${user} password= ${password}",
        unless  => "exit ((Get-ItemProperty -Path HKLM:SYSTEM\\CurrentControlSet\\Services\\${name} -Name \"ObjectName\").ObjectName) -ne \"${user}\"",
        notify  => Exec["ensure-${name}-logon-rights"],
        require => Exec["create-windows-service-${name}"],
      }
    }
    absent: {
      exec { "delete-windows-service-${name}":
        command => "& sc.exe delete ${name}",
        unless => "exit @(Get-Service ${name}).Count -ne 0",
        provider => powershell,
      }
    }
    default: {
      fail('present parameter must be present or absent')
    }
  }
}
