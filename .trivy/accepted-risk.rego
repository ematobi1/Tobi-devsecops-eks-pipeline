# Trivy accepted-risk policy for OWASP Juice Shop (app/)
#
# Juice Shop is a deliberately vulnerable training application. The packages
# below are vulnerable BY DESIGN: hacking challenges depend on them, and
# patching them would remove those challenges. Every other finding still
# fails the pipeline.
#
#   vm2  — sandbox behind the chatbot's code-injection challenge
#          (juicy-chat-bot). Every vm2 advisory is a sandbox escape, which
#          is the point of the challenge.
#
# Review this list when upgrading Juice Shop.
package trivy

import rego.v1

default ignore := false

accepted_packages := {"vm2"}

ignore if input.PkgName in accepted_packages
