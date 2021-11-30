# backup-kvm.sh

Simple script that creates/commits snapshot of KVM virtual machine

##### Create snapshot
`backup-kvm.sh -s -n virtual_machine`  
Creates snapshot near virtual_machine qcow2 file so you can backup it

##### Commit snapshot
`backup-kvm.sh -c -n virtual_machine`
Commits previously created snapshot