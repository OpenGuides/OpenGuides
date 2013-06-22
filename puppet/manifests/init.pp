package {'openguides':
        ensure => present,
        }

package {'vim':
        ensure => present,
        }

package {'cpanminus':
        ensure => present,
        }

package {'liblocal-lib-perl':
        ensure => present,
        }

package {'git-core':
        ensure => present,
        }

# set up local::lib for each user

file {'/etc/profile.d/locallibperl.sh':
      content => 'eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)',
      require => Package['liblocal-lib-perl'],
      }
