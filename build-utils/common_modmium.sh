# variables

# formatting that i totally didn't RIP OUT RUTHLESSLY FROM MOSH
B='\033[1;36m' 
G='\033[1;32m' 
Y='\033[38;5;220m'
R='\033[38;5;203m'
N='\033[0m'    
D='\033[1;90m'
UN='\033[4m' #underline
RUN='\033[24m' #reset underline
# end of formatting
boards="ambassador arkham asuka asurada atlas auron-paine auron-yuna banjo banon bob brask brox brya buddy buddy-cfm butterfly candy caroline cave celes chell cherry clapper constitution coral corsola cyan daisy daisy-skate daisy-spring dedede drallion edgar elm endeavour enguarde eve excelsior expresso falco falco-li fizz fizz-cfm gale gandof geralt glimmer gnawty grunt guado guado-cfm guybrush hana hatch heli jacuzzi kalista kalista-cfm kefka kevin kip kukui lars leon link lulu lumpy mccloud monroe nami nautilus ninja nirva nissa nocturne nyan-big nyan-blaze nyan-kitty octopus orco ovis panther parrot parrot-ivb peach-pi peach-pit peppy puff pyro quawks rammus rauru reef reks relm reven rex rikku rikku-cfm samus sand sarien scarlet sentry setzer skyrim skywalker snappy soraka squawks staryu stout strongbad stumpy sumo swanky terra tidus tricky trogdor ultima veyron-fievel veyron-jaq veyron-jerry veyron-mickey veyron-mighty veyron-minnie veyron-speedy veyron-tiger volteer whirlwind winky wizpig wolf x86-alex x86-alex-he x86-mario x86-zgb x86-zgb-he zako zork"

command -v 7z >/dev/null || alias 7z='7za'
load_shflags() {
	. build-utils/lib/shflags/shflags
}
