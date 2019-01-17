#!/bin/bash

# This is a heavily chopped up version of pstadler's ticker.sh
# (https://github.com/pstadler/ticker.sh).

# To be used in conjunction with the fantastic ledger-cli.

# Append the output of this script to your pricedb file (by default, located at
# ~/.pricedb).

# You will also need to change the $SYMBOLS variable if you want it to
# automatically get a list of stocks from your brokerage account. 

set -e

LANG=en_US.UTF-8
LC_NUMERIC=en_US.UTF-8

function stock_date {
  date "+%Y/%m/%d"
}

function stock_time {
  date "+%H:%M:%S"
}

SYMBOLS=("$@")

if ! $(type jq > /dev/null 2>&1); then
  echo "'jq' is not in the PATH. (See: https://stedolan.github.io/jq/)"
  exit 1
fi

# Change SYMBOLS variable to reflect the account containing stocks for lookup

if [ -z "$SYMBOLS" ]; then
  SYMBOLS=( `ledger commodities ^assets:schwab\ brokerage` )
fi

FIELDS=(symbol marketState regularMarketPrice regularMarketChange regularMarketChangePercent \
  preMarketPrice preMarketChange preMarketChangePercent postMarketPrice postMarketChange postMarketChangePercent)
API_ENDPOINT="https://query1.finance.yahoo.com/v7/finance/quote?lang=en-US&region=US&corsDomain=finance.yahoo.com"

: "${COLOR_BOLD:=\e[1;37m}"
: "${COLOR_GREEN:=\e[32m}"
: "${COLOR_RED:=\e[31m}"
: "${COLOR_RESET:=\e[00m}"

symbols=$(IFS=,; echo "${SYMBOLS[*]}")
fields=$(IFS=,; echo "${FIELDS[*]}")

results=$(curl --silent "$API_ENDPOINT&fields=$fields&symbols=$symbols" \
  | jq '.quoteResponse .result')

query () {
  echo $results | jq -r ".[] | select (.symbol == \"$1\") | .$2"
}

for symbol in $(IFS=' '; echo "${SYMBOLS[*]}"); do
  if [ -z "$(query $symbol 'marketState')" ]; then
    continue
  fi

  if [ $(query $symbol 'marketState') == "PRE" ] \
    && [ "$(query $symbol 'preMarketChange')" != "0" ] \
    && [ "$(query $symbol 'preMarketChange')" != "null" ]; then
    nonRegularMarketSign='*'
    price=$(query $symbol 'preMarketPrice')
    diff=$(query $symbol 'preMarketChange')
    percent=$(query $symbol 'preMarketChangePercent')
  elif [ $(query $symbol 'marketState') != "REGULAR" ] \
    && [ "$(query $symbol 'postMarketChange')" != "0" ] \
    && [ "$(query $symbol 'postMarketChange')" != "null" ]; then
    nonRegularMarketSign='*'
    price=$(query $symbol 'regularMarketPrice')
    diff=$(query $symbol 'postMarketChange')
    percent=$(query $symbol 'postMarketChangePercent')
  else
    nonRegularMarketSign=''
    price=$(query $symbol 'regularMarketPrice')
    diff=$(query $symbol 'regularMarketChange')
    percent=$(query $symbol 'regularMarketChangePercent')
  fi

  printf "P "
  printf $(stock_date)
  printf " "
  printf $(stock_time)
  printf " "
  printf $symbol
  printf " \$"
  printf $price
  printf "\n"

done
