require 'spec_helper_acceptance'

test_name 'TPM'

describe 'Trusted Boot Test' do
  hosts.each do |host|
    if fact_on(host,'osfamily') == 'RedHat'
      install_package(host, 'tboot')
      install_package(host, 'trousers')

      if fact_on(host,'operatingsystemmajrelease').to_s <= '6'
        context 'set a trusted boot kernel in GRUB Legacy' do

          let(:manifest) { %(
            grub_menuentry { 'Trusted Boot':
              default_entry  => true,
              root           => '(hd0,0)',
              kernel         => '/tboot.gz',
              kernel_options => ['loglvl=all','logging=serial,vga,memory','vga_delay=1'],
              modules        => [
                [':preserve:'],
                [
            }
          )}

          # Using puppet_apply as a helper
          it 'should work with no errors' do
            apply_manifest_on(host, manifest, :catch_failures => true)
          end

          it 'should be idempotent' do
            apply_manifest_on(host, manifest, {:catch_changes => true})
          end

          it 'should have set the default to the new entry' do
            result = on(host, %(grubby --info=DEFAULT | grep 'args=')).stdout
            expect(result).to match(/iam=GROOT/)
          end

          it 'should activate on reboot' do
            host.reboot

            result = on(host, %(cat /proc/cmdline)).stdout
            expect(result.split(/\s+/)).to include('iam=GROOT')
          end
        end
      else
        context 'set new default kernel in GRUB2' do
          let(:manifest) { %(
            grub_menuentry { 'Standard':
              default_entry  => true,
              root           => '(hd0,msdos1)',
              kernel         => ':preserve:',
              initrd         => ':preserve:',
              kernel_options => [':preserve:', 'trogdor=BURNINATE']
            }
          )}

          # Using puppet_apply as a helper
          it 'should work with no errors' do
            apply_manifest_on(host, manifest, :catch_failures => true)
          end

          it 'should be idempotent' do
            apply_manifest_on(host, manifest, {:catch_changes => true})
          end

          it 'should have set the default to the new entry' do
            result = on(host, %(grubby --info=DEFAULT)).stdout
            result_hash = {}
            result.each_line do |line|
              line =~ /^\s*(.*?)=(.*)\s*$/
              result_hash[$1.strip] = $2.strip
            end

            expect(result_hash['title']).to eq('Standard')
            expect(result_hash['args']).to match(/trogdor=BURNINATE/)
          end

          it 'should activate on reboot' do
            host.reboot

            result = on(host, %(cat /proc/cmdline)).stdout
            expect(result.split(/\s+/)).to include('trogdor=BURNINATE')
          end
        end
      end
    end
  end
end