require File.dirname(__FILE__) + '/../../test_helper.rb'

class Moonshine::Manifest::RailsTest < Test::Unit::TestCase

  def setup
    @manifest = Moonshine::Manifest::Rails.new
  end

  def test_is_executable
    assert @manifest.executable?
  end

  def test_loads_gems_from_config_hash
    assert @manifest.class.recipes.map(&:first).include?(:rails_gems)
    @manifest.configure(:gems => [ { :name => 'jnewland-pulse', :source => 'http://gems.github.com/' } ])
    @manifest.rails_gems
    assert_not_nil Moonshine::Manifest::Rails.configuration[:gems]
    Moonshine::Manifest::Rails.configuration[:gems].each do |gem|
      assert_not_nil gem_resource = @manifest.puppet_resources[Puppet::Type::Package][gem[:name]]
      assert_equal gem[:source], gem_resource.params[:source].value
      assert_equal :gem, gem_resource.params[:provider].value
    end
  end

  def test_creates_directories
    assert @manifest.class.recipes.map(&:first).include?(:rails_directories)
    config = {
      :application => 'foo',
      :user => 'foo',
      :deploy_to => '/srv/foo'
    }
    @manifest.expects(:configuration).at_least_once.returns(config)
    @manifest.rails_directories
    assert_not_nil shared_dir = @manifest.puppet_resources[Puppet::Type::File]["/srv/foo/shared"]
    assert_equal :directory, shared_dir.params[:ensure].value
    assert_equal 'foo', shared_dir.params[:owner].value
    assert_equal 'foo', shared_dir.params[:group].value
  end

  def test_installs_apache
    assert @manifest.class.recipes.map(&:first).include?(:apache_server)
    @manifest.apache_server
    assert_not_nil apache = @manifest.puppet_resources[Puppet::Type::Service]["apache2"]
    assert_equal @manifest.package('apache2-mpm-worker').to_s, apache.params[:require].value.to_s
  end

  def test_installs_passenger_gem
    assert @manifest.class.recipes.map(&:first).include?(:passenger_gem)
    @manifest.passenger_configure_gem_path
    @manifest.passenger_gem
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["passenger"]
  end

  def test_installs_passenger_module
    assert @manifest.class.recipes.map(&:first).include?(:passenger_apache_module)
    @manifest.passenger_configure_gem_path
    @manifest.passenger_apache_module
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]['apache2-threaded-dev']
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]['/etc/apache2/mods-available/passenger.load']
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]['/etc/apache2/mods-available/passenger.conf']
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Exec].find { |n, r| r.params[:command].value == '/usr/sbin/a2enmod passenger' }
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Exec].find { |n, r| r.params[:command].value == '/usr/bin/ruby -S rake clean apache2' }
  end

  def test_configures_passenger_vhost
    assert @manifest.class.recipes.map(&:first).include?(:passenger_site)
    @manifest.passenger_configure_gem_path
    @manifest.passenger_site
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"]
    assert_match /RailsAllowModRewrite Off/, @manifest.puppet_resources[Puppet::Type::File]["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].params[:content].value
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Exec].find { |n, r| r.params[:command].value == '/usr/sbin/a2dissite default' }
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Exec].find { |n, r| r.params[:command].value == "/usr/sbin/a2ensite #{@manifest.configuration[:application]}" }
  end

  def test_passenger_vhost_configuration
    assert @manifest.class.recipes.map(&:first).include?(:passenger_site)
    @manifest.passenger_configure_gem_path
    @manifest.configure(:passenger => { :allow_mod_rewrite => true })
    @manifest.passenger_site
    assert_match /RailsAllowModRewrite On/, @manifest.puppet_resources[Puppet::Type::File]["/etc/apache2/sites-available/#{@manifest.configuration[:application]}"].params[:content].value
  end

  def test_installs_postfix
    assert @manifest.class.recipes.map(&:first).include?(:postfix)
    @manifest.postfix
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["postfix"]
  end

  def test_installs_ntp
    assert @manifest.class.recipes.map(&:first).include?(:ntp)
    @manifest.ntp
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Service]["ntp"]
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["ntp"]
  end

  def test_installs_cron
    assert @manifest.class.recipes.map(&:first).include?(:cron_packages)
    @manifest.cron_packages
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Service]["cron"]
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["cron"]
  end

  def test_sets_default_time_zone
    assert @manifest.class.recipes.map(&:first).include?(:time_zone)
    @manifest.time_zone
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]["/etc/timezone"]
    assert_not_nil @manifest.puppet_resources[Puppet::Type::Package]["/etc/localtime"]
    assert_equal '/usr/share/zoneinfo/UTC', @manifest.puppet_resources[Puppet::Type::File]["/etc/localtime"].params[:ensure].value
  end

  def test_sets_default_time_zone
    assert @manifest.class.recipes.map(&:first).include?(:time_zone)
    @manifest.configure(:time_zone => nil)
    @manifest.time_zone
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]["/etc/timezone"]
    assert_equal "UTC\n", @manifest.puppet_resources[Puppet::Type::File]["/etc/timezone"].params[:content].value
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]["/etc/localtime"]
    assert_equal '/usr/share/zoneinfo/UTC', @manifest.puppet_resources[Puppet::Type::File]["/etc/localtime"].params[:ensure].value
  end

  def test_sets_configured_time_zone
    assert @manifest.class.recipes.map(&:first).include?(:time_zone)
    @manifest.configure(:time_zone => 'America/New_York')
    @manifest.time_zone
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]["/etc/timezone"]
    assert_equal "America/New_York\n", @manifest.puppet_resources[Puppet::Type::File]["/etc/timezone"].params[:content].value
    assert_not_nil @manifest.puppet_resources[Puppet::Type::File]["/etc/localtime"]
    assert_equal '/usr/share/zoneinfo/America/New_York', @manifest.puppet_resources[Puppet::Type::File]["/etc/localtime"].params[:ensure].value
  end

end