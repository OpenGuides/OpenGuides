package {'libdbd-sqlite3-perl':
        ensure => present,
        }

package {'libgeo-coordinates-osgb-perl':
        ensure => present,
        }

package {'libgeo-coordinates-itm-perl':
        ensure => present,
        }

package {'libtest-html-content-perl':
        ensure => present,
        }

package {'libtest-pod-perl':
        ensure => present,
        }

package {'openguides':
        ensure => present,
        require => Package['libgeo-coordinates-osgb-perl','libdbd-sqlite3-perl','libgeo-coordinates-itm-perl','libtest-html-content-perl','libtest-pod-perl']
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
