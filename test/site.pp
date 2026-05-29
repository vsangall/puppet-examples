# Test fixture: Create stub git repository for app deployment
class test_git_repo {
  $repo_path = '/tmp/test-app-repo'

  # Create repository directory
  file { $repo_path:
    ensure => directory,
    mode   => '0755',
  }

  # Create app.py
  file { "${repo_path}/app.py":
    ensure  => file,
    mode    => '0644',
    content => @(EOF)
      #!/usr/bin/env python3
      """Simple test application"""

      def main():
          print("Test application")

      if __name__ == "__main__":
          main()
      | EOF
    ,
    require => File[$repo_path],
  }

  # Create requirements.txt
  file { "${repo_path}/requirements.txt":
    ensure  => file,
    mode    => '0644',
    content => @(EOF)
      fastapi==0.104.1
      uvicorn==0.24.0
      gunicorn==21.2.0
      psycopg[binary]>=3.2.2
      alembic==1.13.1
      | EOF
    ,
    require => File[$repo_path],
  }

  # Create alembic.ini
  file { "${repo_path}/alembic.ini":
    ensure  => file,
    mode    => '0644',
    content => @(EOF)
      [alembic]
      script_location = migrations
      | EOF
    ,
    require => File[$repo_path],
  }

  # Create migrations directory
  file { "${repo_path}/migrations":
    ensure  => directory,
    mode    => '0755',
    require => File[$repo_path],
  }

  # Initialize git repository and commit
  exec { 'init_test_git_repo':
    command => "git init && git config user.email 'test@example.com' && git config user.name 'Test User' && git add . && git commit -m 'Initial commit'",
    cwd     => $repo_path,
    path    => ['/usr/bin', '/bin'],
    creates => "${repo_path}/.git/HEAD",
    require => [
      File["${repo_path}/app.py"],
      File["${repo_path}/requirements.txt"],
      File["${repo_path}/alembic.ini"],
      File["${repo_path}/migrations"],
    ],
  }
}

node default {
  # Create test git repository before deploying app
  include test_git_repo

  include profile_haproxy
  include profile_app_stack
  include profile_redis_cluster

  # Ensure test repo is created before app deployment
  Class['test_git_repo'] -> Class['profile_app_stack::app']
}
