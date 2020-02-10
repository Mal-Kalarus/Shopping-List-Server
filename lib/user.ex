##############################################################################
# Assignment : 5
# Author     : MALGORZATA KALARUS
# Email      : mkalarus@uwo.ca
#
# User module  hold a struct that represents a user.
##############################################################################

# creates a user struct  that represents the user. to be used in UserStore
# Defines 2 required keys
defmodule User do
  @enforce_keys [:username, :password]
  defstruct [:username, :password]
end
