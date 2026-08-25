-- DYK bulk seed: 10 cities + 15 London hotspots + facts
-- Generated from Cowork JSON. Safe to run once in Supabase SQL Editor.

-- 1) Cities (London published; others draft until filled). Skips duplicates by city name.
insert into public.citypacks (name, city, country, description, price_sek, is_published)
select $dyk$London Explorer$dyk$, $dyk$London$dyk$, $dyk$United Kingdom$dyk$, $dyk$From royal fortresses to haunted houses in Mayfair – discover a thousand years of London history, myths and curiosities right in your headphones. 15 hand-picked places the guidebooks miss.$dyk$, 49, true
where not exists (select 1 from public.citypacks where city = $dyk$London$dyk$);

insert into public.citypacks (name, city, country, description, price_sek, is_published)
select $dyk$Paris Explorer$dyk$, $dyk$Paris$dyk$, $dyk$France$dyk$, $dyk$Wander through the City of Light with stories of revolutions, artists and hidden passages. From Notre-Dame to the secrets of Montmartre – Paris like you've never heard it before.$dyk$, 49, false
where not exists (select 1 from public.citypacks where city = $dyk$Paris$dyk$);

insert into public.citypacks (name, city, country, description, price_sek, is_published)
select $dyk$Rome Explorer$dyk$, $dyk$Rome$dyk$, $dyk$Italy$dyk$, $dyk$Walk in the footsteps of gladiators through the Eternal City. Ancient emperors, baroque fountains and legends that have lived for over 2,000 years – told exactly where they happened.$dyk$, 49, false
where not exists (select 1 from public.citypacks where city = $dyk$Rome$dyk$);

insert into public.citypacks (name, city, country, description, price_sek, is_published)
select $dyk$Barcelona Explorer$dyk$, $dyk$Barcelona$dyk$, $dyk$Spain$dyk$, $dyk$Gaudí's dreamworlds, Gothic alleys and Mediterranean pulse. Discover Barcelona's fantastical architecture and Catalan history with your ears – one step at a time.$dyk$, 49, false
where not exists (select 1 from public.citypacks where city = $dyk$Barcelona$dyk$);

insert into public.citypacks (name, city, country, description, price_sek, is_published)
select $dyk$Berlin Explorer$dyk$, $dyk$Berlin$dyk$, $dyk$Germany$dyk$, $dyk$A city where history still lingers in the walls. From the fall of the Wall to the golden twenties – Berlin's dramatic stories unlock exactly where you're standing.$dyk$, 49, false
where not exists (select 1 from public.citypacks where city = $dyk$Berlin$dyk$);

insert into public.citypacks (name, city, country, description, price_sek, is_published)
select $dyk$Amsterdam Explorer$dyk$, $dyk$Amsterdam$dyk$, $dyk$Netherlands$dyk$, $dyk$Canals, the Golden Age and a rebellious spirit of freedom. Hear the stories behind the leaning houses, Rembrandt's masterpieces and the city's hidden courtyards.$dyk$, 49, false
where not exists (select 1 from public.citypacks where city = $dyk$Amsterdam$dyk$);

insert into public.citypacks (name, city, country, description, price_sek, is_published)
select $dyk$Vienna Explorer$dyk$, $dyk$Vienna$dyk$, $dyk$Austria$dyk$, $dyk$Emperors, composers and coffee-house culture. Journey through Habsburg splendour and hear the music, scandals and love stories that shaped Vienna.$dyk$, 49, false
where not exists (select 1 from public.citypacks where city = $dyk$Vienna$dyk$);

insert into public.citypacks (name, city, country, description, price_sek, is_published)
select $dyk$Prague Explorer$dyk$, $dyk$Prague$dyk$, $dyk$Czech Republic$dyk$, $dyk$Alchemists, astronomical clocks and golden lanes – Prague is a fairy tale in stone. Discover the magical city on the Vltava through legends and true history.$dyk$, 49, false
where not exists (select 1 from public.citypacks where city = $dyk$Prague$dyk$);

insert into public.citypacks (name, city, country, description, price_sek, is_published)
select $dyk$Lisbon Explorer$dyk$, $dyk$Lisbon$dyk$, $dyk$Portugal$dyk$, $dyk$Explorers, earthquakes and fado in the alleyways. Lisbon's seven hills hide the stories of the seafaring empire that changed the world.$dyk$, 49, false
where not exists (select 1 from public.citypacks where city = $dyk$Lisbon$dyk$);

insert into public.citypacks (name, city, country, description, price_sek, is_published)
select $dyk$Athens Explorer$dyk$, $dyk$Athens$dyk$, $dyk$Greece$dyk$, $dyk$The cradle of democracy and the city of the gods. Stand where Socrates once debated and hear the myths of Athena, the Acropolis and everyday life in antiquity come alive.$dyk$, 49, false
where not exists (select 1 from public.citypacks where city = $dyk$Athens$dyk$);

-- 2) London hotspots (linked to the London city). Skips existing slugs.
insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, category, subcategory, sort_order)
values (
  (select id from public.citypacks where city = $dyk$London$dyk$ limit 1), $dyk$tower-of-london$dyk$, $dyk$Tower of London$dyk$, $dyk$The fortress guarding London for 950 years$dyk$, $dyk$Rising before you is the Tower of London – a fortress that has witnessed nearly a thousand years of England's most dramatic history. William the Conqueror began the White Tower, the great keep at its heart, around 1078 to show the conquered city of London exactly who was in charge. Since then, the Tower has served as royal palace, prison, mint, armoury and even a zoo housing lions and a polar bear. But it is as a prison and place of execution that it became infamous. Elizabeth I was held captive here as a young princess, and her mother Anne Boleyn was executed here in 1536 on the orders of Henry VIII. Today the Tower is guarded by the Yeoman Warders, better known as Beefeaters, and the British Crown Jewels are kept here behind armoured glass. Every evening for over 700 years, the gates have been locked in the venerable Ceremony of the Keys. And then there are the ravens – but that's a story all of its own. Welcome to England's bloodiest and most fascinating building.$dyk$,
  51.5081, -0.0759, 80, $dyk$1078$dyk$, true, $dyk$history$dyk$, $dyk$building$dyk$, 0
)
on conflict (slug) do nothing;

insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, category, subcategory, sort_order)
values (
  (select id from public.citypacks where city = $dyk$London$dyk$ limit 1), $dyk$tower-bridge$dyk$, $dyk$Tower Bridge$dyk$, $dyk$The queen of bridges over the Thames$dyk$, $dyk$Tower Bridge is probably the most famous bridge in the world – and the one most tourists insist on calling London Bridge. It opened in 1894 after eight years of construction and was a technical marvel: a bascule bridge whose two 1,000-ton halves could be raised in just minutes using steam-driven hydraulics, allowing tall ships to reach the docks upstream. The neo-Gothic towers are actually steel frames clad in stone, designed to harmonise with their neighbour, the Tower of London. The bascules are still raised hundreds of times a year, now powered by electricity, and river traffic always takes priority over road traffic – even presidents have had to wait. Up in the walkways between the towers, 42 metres above the Thames, you can now walk across a glass floor and watch the traffic pass beneath your feet. The walkways were originally built so pedestrians could cross even when the bridge was open, but they quickly became a haunt for pickpockets and were closed in 1910. Today they are the bridge's biggest attraction.$dyk$,
  51.5055, -0.0754, 70, $dyk$1894$dyk$, false, $dyk$history$dyk$, $dyk$building$dyk$, 1
)
on conflict (slug) do nothing;

insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, category, subcategory, sort_order)
values (
  (select id from public.citypacks where city = $dyk$London$dyk$ limit 1), $dyk$big-ben$dyk$, $dyk$Big Ben$dyk$, $dyk$The most famous clock in the world$dyk$, $dyk$You are standing before the most photographed clock tower in the world – and here's a secret: Big Ben isn't actually the tower. Big Ben is the name of the 13.7-ton Great Bell hanging inside it. The tower itself was long known simply as the Clock Tower, but was renamed Elizabeth Tower in 2012 to honour Queen Elizabeth II's sixty years on the throne. The tower was completed in 1859 as part of the new Houses of Parliament, after the old palace burned down in 1834. Within months, the Great Bell cracked – a hammer that was too heavy had been used – and it is in fact that cracked bell you still hear today, rotated so the hammer strikes an undamaged spot. That's what gives the chime its utterly distinctive tone. The clock mechanism is famed for its precision: when it needs adjusting, old penny coins are placed on the pendulum – one coin changes the speed by two-fifths of a second per day. Big Ben's chimes are broadcast live on BBC radio, a tradition since 1924, and for Britons these notes are the very sound of the nation.$dyk$,
  51.50072, -0.12462, 50, $dyk$1859$dyk$, true, $dyk$history$dyk$, $dyk$building$dyk$, 2
)
on conflict (slug) do nothing;

insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, category, subcategory, sort_order)
values (
  (select id from public.citypacks where city = $dyk$London$dyk$ limit 1), $dyk$st-pauls-cathedral$dyk$, $dyk$St Paul's Cathedral$dyk$, $dyk$Wren's masterpiece that defied the bombs$dyk$, $dyk$When the Great Fire of 1666 reduced medieval London to ashes, the architect Christopher Wren was given the chance to create something entirely new. The result, completed in 1710, is the cathedral before you – crowned by one of the largest domes in the world, 111 metres high, which dominated London's skyline for over 250 years. No building was allowed to rise higher than St Paul's until 1963. Inside the dome is the famous Whispering Gallery, where a whisper against the wall can be heard 30 metres away on the opposite side – an acoustic quirk that has baffled visitors for centuries. The cathedral's most iconic moment came during the Blitz in December 1940, when the photograph of the dome rising unscathed from smoke and flames became a symbol of British resilience. Churchill ordered that the cathedral be saved at all costs, and volunteer fire watchers slept on the roof. Churchill's state funeral was held here in 1965, and Prince Charles married Diana here in 1981. In the crypt rest Nelson, Wellington – and Wren himself, beneath the words: 'Reader, if you seek his monument – look around you.'$dyk$,
  51.5138, -0.0984, 70, $dyk$1710$dyk$, false, $dyk$history$dyk$, $dyk$building$dyk$, 3
)
on conflict (slug) do nothing;

insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, category, subcategory, sort_order)
values (
  (select id from public.citypacks where city = $dyk$London$dyk$ limit 1), $dyk$rosetta-stone-british-museum$dyk$, $dyk$The Rosetta Stone, British Museum$dyk$, $dyk$The stone that cracked the hieroglyphic code$dyk$, $dyk$Inside the British Museum, just steps from the entrance, stands the museum's most visited object: the Rosetta Stone. It looks unremarkable – a grey, chipped slab of rock – but this is the key that unlocked an entire civilisation. The stone was carved in 196 BC and bears a priestly decree honouring the young pharaoh Ptolemy V, written three times: in Egyptian hieroglyphs, in Egyptian Demotic script, and in classical Greek. When French soldiers found it in 1799 near the town of Rashid – Rosetta – in the Nile Delta, scholars immediately grasped its value: since the Greek could be read, there was finally a way to decipher the hieroglyphs, which had been a mystery for 1,400 years. The race was won in 1822 by the Frenchman Jean-François Champollion, who cracked the code and in doing so founded Egyptology as a science. The stone passed into British hands after Napoleon's defeat in Egypt and has been displayed at the British Museum since 1802. Egypt has repeatedly requested its return – the debate over where it truly belongs continues to this day.$dyk$,
  51.5194, -0.127, 70, $dyk$196 BC$dyk$, false, $dyk$history$dyk$, $dyk$work_of_art$dyk$, 4
)
on conflict (slug) do nothing;

insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, category, subcategory, sort_order)
values (
  (select id from public.citypacks where city = $dyk$London$dyk$ limit 1), $dyk$nelsons-column$dyk$, $dyk$Nelson's Column, Trafalgar Square$dyk$, $dyk$The naval hero watching over London$dyk$, $dyk$Atop the 52-metre granite column before you stands Admiral Horatio Nelson – the man who saved Britain from Napoleon's invasion plans but paid with his life. At the Battle of Trafalgar in 1805, Nelson's fleet crushed the combined Franco-Spanish force without losing a single ship. Nelson himself was struck by a French sharpshooter's bullet in the midst of the fighting and died aboard his flagship HMS Victory, hours after victory was secured. His famous final signal to the fleet – 'England expects that every man will do his duty' – can still be quoted by Britons from memory. The column was erected in 1843, and the statue on top is over five metres tall, even if it looks tiny from down here. The four bronze lions at the base, sculpted by the artist Edwin Landseer, arrived only in 1867 – twenty-four years late. Landseer was a painter of animals, not a sculptor, and is said to have worked from a dead lion from the zoo that began to decompose before he finished. Look closely: the lions' backs are concave like a dog's, which real lions' backs are not. Nelson gazes south-west – towards Trafalgar and the sea.$dyk$,
  51.50775, -0.12797, 60, $dyk$1843$dyk$, false, $dyk$history$dyk$, $dyk$historical_figure$dyk$, 5
)
on conflict (slug) do nothing;

insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, category, subcategory, sort_order)
values (
  (select id from public.citypacks where city = $dyk$London$dyk$ limit 1), $dyk$st-jamess-park$dyk$, $dyk$St James's Park$dyk$, $dyk$A royal oasis with pelicans$dyk$, $dyk$You are standing in London's oldest royal park – a green lung nestled between three palaces: Buckingham Palace, St James's Palace and Westminster. Henry VIII bought the land in 1532; back then it was marshy ground where pigs grazed. He drained it and turned it into a royal deer park. James I then kept an exotic menagerie here in the early 1600s, complete with camels and crocodiles, and Charles II opened the park to the public, strolling here himself with his mistresses and his spaniels. Today's romantic landscape with its winding lake was created in the 1820s by the architect John Nash, the same man who shaped Regent Street and the façade of Buckingham Palace. The park's most beloved residents are the pelicans – the first arrived in 1664 as a gift from the Russian ambassador, and their successors have lived by the lake ever since. Make your way to the bridge over the lake: the view eastward towards the rooftops and turrets of Horse Guards is often called one of the loveliest in London. This is the perfect place to simply sink into a deckchair and breathe.$dyk$,
  51.5027, -0.1348, 80, $dyk$1532$dyk$, true, $dyk$otium$dyk$, $dyk$natural_spaces$dyk$, 6
)
on conflict (slug) do nothing;

insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, category, subcategory, sort_order)
values (
  (select id from public.citypacks where city = $dyk$London$dyk$ limit 1), $dyk$tate-modern$dyk$, $dyk$Tate Modern$dyk$, $dyk$The power station turned temple of art$dyk$, $dyk$The mighty brick colossus before you was once Bankside Power Station – an oil-fired plant that supplied London with electricity. The building was designed by Giles Gilbert Scott, the same architect who created Britain's iconic red telephone box, and the power station closed in 1981. Instead of demolition, salvation came from art: after a spectacular conversion by Swiss architects Herzog & de Meuron, Tate Modern opened in 2000 and almost instantly became one of the most visited modern art museums in the world. Its heart is the dizzying Turbine Hall – 35 metres high and 152 metres long, where the turbines once stood. It now hosts colossal art installations that have become world-famous, such as Olafur Eliasson's artificial sun in 2003, which drew millions of visitors who lay down on the floor to bask in its glow. The collections span Picasso, Dalí, Warhol, Rothko and contemporary art from across the globe – and the main displays are free to visit. Don't miss the viewing terrace in the Blavatnik Building, the 2016 extension, with panoramic views over the Thames and the dome of St Paul's directly across the river.$dyk$,
  51.5076, -0.0994, 70, $dyk$2000$dyk$, false, $dyk$otium$dyk$, $dyk$art$dyk$, 7
)
on conflict (slug) do nothing;

insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, category, subcategory, sort_order)
values (
  (select id from public.citypacks where city = $dyk$London$dyk$ limit 1), $dyk$covent-garden$dyk$, $dyk$Covent Garden$dyk$, $dyk$From vegetable market to street theatre$dyk$, $dyk$The square you're standing on has been London's living room for nearly 400 years. The name comes from 'convent garden' – this was once the kitchen garden of Westminster Abbey. In the 1630s the architect Inigo Jones designed England's first classical piazza here, inspired by Italian squares, and from 1654 a fruit and vegetable market grew up that would become London's largest. The handsome market building at its centre was built in 1830. For nearly three centuries this was a bustle of traders, flower girls and porters – the setting where George Bernard Shaw had the flower girl Eliza Doolittle meet Professor Higgins in his play Pygmalion, better known as the musical My Fair Lady. In 1974 the wholesale market moved out, and the square transformed into today's blend of shops, cafés and, above all, street performers. Covent Garden has a special place in theatre history: the Royal Opera House stands here, and as early as 1662 the diarist Samuel Pepys watched England's first recorded Punch and Judy puppet show on this very piazza. The performers you see today have passed genuine auditions – and the quality shows.$dyk$,
  51.5117, -0.1226, 70, $dyk$1830$dyk$, false, $dyk$otium$dyk$, $dyk$leisure$dyk$, 8
)
on conflict (slug) do nothing;

insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, category, subcategory, sort_order)
values (
  (select id from public.citypacks where city = $dyk$London$dyk$ limit 1), $dyk$abbey-road-crossing$dyk$, $dyk$The Abbey Road Crossing$dyk$, $dyk$The most famous zebra stripes on Earth$dyk$, $dyk$An ordinary zebra crossing on a quiet residential street – and yet tourists from all over the world stand here waiting for a gap in the traffic to take exactly the same photo. At half past eleven on the morning of 8 August 1969, John, Ringo, Paul and George stepped out of the EMI studio behind you and walked across the road while photographer Iain Macmillan stood on a stepladder in the middle of the street. A policeman held up the traffic. The whole shoot took ten minutes and produced six frames – the fifth became the cover of Abbey Road, the last album the Beatles ever recorded. Paul walking barefoot was pure chance – it was a hot day and he kicked off his sandals – but the detail fuelled the bizarre 'Paul is dead' conspiracy theory, in which the cover was said to depict a funeral procession. The studio behind the wall, Abbey Road Studios, opened back in 1931, inaugurated by the composer Edward Elgar, and is still going strong – everything from Pink Floyd's Dark Side of the Moon to the scores for Star Wars and The Lord of the Rings has been recorded here. In 2010 the crossing was granted heritage status – one of very few road crossings in the world with that protection.$dyk$,
  51.53216, -0.17739, 50, $dyk$1969$dyk$, true, $dyk$funfact$dyk$, null, 9
)
on conflict (slug) do nothing;

insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, category, subcategory, sort_order)
values (
  (select id from public.citypacks where city = $dyk$London$dyk$ limit 1), $dyk$platform-nine-and-three-quarters$dyk$, $dyk$Platform 9¾, King's Cross$dyk$, $dyk$Where the journey to Hogwarts begins$dyk$, $dyk$Inside King's Cross station is a place that shouldn't exist: Platform 9¾. This is where J.K. Rowling had Harry Potter and every Hogwarts student board the Hogwarts Express, by running straight at the brick wall between platforms 9 and 10. Since the books became a global phenomenon after their 1997 debut, the station has turned into a pilgrimage site, and the station's management has embraced it with a wink: in the concourse hangs a 'Platform 9¾' sign, and beneath it a luggage trolley that appears to be passing through the wall – half of it has already 'vanished' inside. The queue to be photographed wearing a scarf in your Hogwarts house colours can be long, and there's a Harry Potter shop right next door. The funny part is that Rowling herself has admitted to a mistake: when she wrote the scene she was picturing the platforms at Euston station, not King's Cross – at the real King's Cross, platforms 9 and 10 are separated by tracks, not a wall. The films solved this by shooting at platforms 4 and 5. The station itself, incidentally, is a Victorian masterpiece dating from 1852.$dyk$,
  51.53195, -0.124, 60, $dyk$1997$dyk$, false, $dyk$funfact$dyk$, null, 10
)
on conflict (slug) do nothing;

insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, category, subcategory, sort_order)
values (
  (select id from public.citypacks where city = $dyk$London$dyk$ limit 1), $dyk$trafalgar-square-police-box$dyk$, $dyk$Britain's Smallest Police Station$dyk$, $dyk$The police station inside a lamp post$dyk$, $dyk$In the south-east corner of Trafalgar Square stands what looks like an unusually fat granite lamp post. Look closer: it has a door, narrow window slits – and is often called Britain's smallest police station. The story begins in the 1920s, when Trafalgar Square was London's natural stage for demonstrations and protests. The police wanted a lookout post at the centre of the action, but the public objected to plans for a police box that would spoil the famous square. The solution in 1926 was ingeniously discreet: one of the square's massive granite pillars was simply hollowed out and fitted with an interior. Inside there was room for a single constable, with a telephone line direct to headquarters. When the receiver was lifted, the lamp on top began to flash, alerting nearby officers that backup was needed. Through the observation slits, the constable could discreetly keep watch over the entire square. The space is said to have held two prisoners in an emergency – though extremely snugly. Today the police have abandoned their smallest station, and the historic lookout has been given a rather more prosaic assignment: it's used as a storage cupboard by Westminster's cleaning staff.$dyk$,
  51.50737, -0.12706, 40, $dyk$1926$dyk$, true, $dyk$funfact$dyk$, null, 11
)
on conflict (slug) do nothing;

insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, category, subcategory, sort_order)
values (
  (select id from public.citypacks where city = $dyk$London$dyk$ limit 1), $dyk$london-stone$dyk$, $dyk$London Stone$dyk$, $dyk$The stone that protects London$dyk$, $dyk$Behind a small grille in the façade of 111 Cannon Street sits an unremarkable lump of limestone, barely half a metre wide. Most people walk past without realising this is London Stone – perhaps the most myth-laden object in the city. The stone is mentioned in writing as early as around 1100, when it was already a famous landmark; in the Middle Ages, addresses were given in relation to it. What it originally was, nobody knows: theories range from a Roman milestone to a druidic altar or a magical guardian stone. Legend has it that the stone was brought here by Brutus of Troy, London's mythical founder, and that 'so long as the Stone of Brutus is safe, so long shall London flourish'. If the stone is destroyed, the city falls. In 1450 the rebel leader Jack Cade rode into London, struck the stone with his sword and declared himself lord of the city – a scene Shakespeare immortalised in Henry VI. The stone has survived both the Great Fire of 1666 and the bombs of the Blitz, and when it was temporarily moved to the Museum of London in 2016, the press muttered that the city was in peril. Since 2018 it has been back in its rightful place. London still stands – for now.$dyk$,
  51.51151, -0.08955, 40, $dyk$c. 1100$dyk$, false, $dyk$headline$dyk$, null, 12
)
on conflict (slug) do nothing;

insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, category, subcategory, sort_order)
values (
  (select id from public.citypacks where city = $dyk$London$dyk$ limit 1), $dyk$fifty-berkeley-square$dyk$, $dyk$50 Berkeley Square$dyk$, $dyk$The most haunted house in London$dyk$, $dyk$The elegant 18th-century townhouse before you looks harmless enough – but in Victorian times, hardly anyone dared approach number 50 Berkeley Square. The house was built around 1750 and was once home to Prime Minister George Canning. But it is the attic room that made the address infamous as 'the most haunted house in London'. According to legend, the room is haunted by a young woman who threw herself from the top floor to escape a cruel relative; her spirit is said to appear as a brown mist – and anyone who sees it is frightened into madness or death. The stories flourished throughout the 19th century: a nobleman who wagered he could spend a night in the room was found paralysed with terror, and in the most famous version, from 1887, two sailors broke in for the night – one fled, and the other was found dead, impaled on the railings outside. Sceptics point out that the house's eccentric owner Thomas Myers, who lived here alone and increasingly unkempt in the 1860s, probably gave rise to the rumours of figures at the windows. Since the 1930s the antiquarian booksellers Maggs Bros have occupied the building – and the staff reported, officially at least, no ghosts.$dyk$,
  51.50986, -0.1465, 40, $dyk$1750$dyk$, false, $dyk$headline$dyk$, null, 13
)
on conflict (slug) do nothing;

insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, category, subcategory, sort_order)
values (
  (select id from public.citypacks where city = $dyk$London$dyk$ limit 1), $dyk$sweeney-todd-fleet-street$dyk$, $dyk$Sweeney Todd's Barber Shop$dyk$, $dyk$The demon barber of Fleet Street$dyk$, $dyk$186 Fleet Street, right next to the church of St Dunstan-in-the-West – this is where London's bloodiest legend is said to have unfolded. According to the tale, the barber Sweeney Todd ran his shop at this very address. Customers were seated in a specially built chair positioned over a trapdoor; with a flick of a lever, the chair tipped backwards and the victim plunged into the cellar, where Todd cut their throats with his razor. The bodies – over a hundred, according to legend – were then turned into the filling of the meat pies sold by his accomplice Mrs Lovett, whose pie shop stood a short distance away on Bell Yard. The customers ate in blissful ignorance, and the pies are said to have been extremely popular. But did Sweeney Todd really exist? Almost certainly not. The story first appeared in 1846–47 as the serial 'The String of Pearls' in a penny dreadful, the cheap horror literature of the Victorian era, and no court records or contemporary sources support the existence of any demon barber. Yet the legend refuses to die: it has become stage plays, Stephen Sondheim's acclaimed 1979 musical and Tim Burton's 2007 film. So feel free to get a haircut in London – just maybe not here.$dyk$,
  51.51422, -0.10893, 40, $dyk$1846$dyk$, false, $dyk$headline$dyk$, null, 14
)
on conflict (slug) do nothing;

-- 3) Facts (idempotent: clears then re-inserts per hotspot).
delete from public.hotspot_facts where hotspot_id = (select id from public.hotspots where slug = $dyk$tower-of-london$dyk$);
insert into public.hotspot_facts (hotspot_id, text, sort_order)
values
  ((select id from public.hotspots where slug = $dyk$tower-of-london$dyk$), $dyk$Legend says the kingdom will fall if the Tower's six ravens ever fly away – so their wings are clipped and a dedicated 'Ravenmaster' cares for them daily.$dyk$, 0),
  ((select id from public.hotspots where slug = $dyk$tower-of-london$dyk$), $dyk$In the 13th century a polar bear lived at the Tower – it was allowed to swim and fish in the Thames on a leash.$dyk$, 1),
  ((select id from public.hotspots where slug = $dyk$tower-of-london$dyk$), $dyk$The Crown Jewels kept here include Cullinan I, one of the largest cut diamonds in the world at 530 carats.$dyk$, 2),
  ((select id from public.hotspots where slug = $dyk$tower-of-london$dyk$), $dyk$The Ceremony of the Keys has taken place every night for over 700 years – it was once delayed by a bomb during the Blitz, but still went ahead.$dyk$, 3);

delete from public.hotspot_facts where hotspot_id = (select id from public.hotspots where slug = $dyk$tower-bridge$dyk$);
insert into public.hotspot_facts (hotspot_id, text, sort_order)
values
  ((select id from public.hotspots where slug = $dyk$tower-bridge$dyk$), $dyk$In 1952, bus driver Albert Gunter had to accelerate and 'jump' his double-decker across the gap when the bridge suddenly began to open beneath him – he made it, and received a £10 reward.$dyk$, 0),
  ((select id from public.hotspots where slug = $dyk$tower-bridge$dyk$), $dyk$In 1968 a Hawker Hunter fighter jet illegally flew BETWEEN the bridge's towers in protest – the pilot was arrested after landing.$dyk$, 1),
  ((select id from public.hotspots where slug = $dyk$tower-bridge$dyk$), $dyk$The bridge still opens around 800 times a year, and ships always have priority over cars.$dyk$, 2),
  ((select id from public.hotspots where slug = $dyk$tower-bridge$dyk$), $dyk$The towers look like stone but are steel skeletons clad in granite and Portland stone.$dyk$, 3);

delete from public.hotspot_facts where hotspot_id = (select id from public.hotspots where slug = $dyk$big-ben$dyk$);
insert into public.hotspot_facts (hotspot_id, text, sort_order)
values
  ((select id from public.hotspots where slug = $dyk$big-ben$dyk$), $dyk$The bell known as Big Ben has had a crack since 1859 – it's what gives the chime its distinctive tone.$dyk$, 0),
  ((select id from public.hotspots where slug = $dyk$big-ben$dyk$), $dyk$The clock is fine-tuned with old penny coins placed on the pendulum: one coin changes the rate by 0.4 seconds per day.$dyk$, 1),
  ((select id from public.hotspots where slug = $dyk$big-ben$dyk$), $dyk$The tower leans about 0.26 degrees to the north-west – visible to the naked eye if you look closely.$dyk$, 2),
  ((select id from public.hotspots where slug = $dyk$big-ben$dyk$), $dyk$During the Second World War the clock kept chiming even as Parliament was bombed – the tower survived the Blitz.$dyk$, 3);

delete from public.hotspot_facts where hotspot_id = (select id from public.hotspots where slug = $dyk$st-pauls-cathedral$dyk$);
insert into public.hotspot_facts (hotspot_id, text, sort_order)
values
  ((select id from public.hotspots where slug = $dyk$st-pauls-cathedral$dyk$), $dyk$No building in London was permitted to stand taller than St Paul's dome until 1963.$dyk$, 0),
  ((select id from public.hotspots where slug = $dyk$st-pauls-cathedral$dyk$), $dyk$In the Whispering Gallery, a whisper against the wall can be heard 30 metres away on the opposite side.$dyk$, 1),
  ((select id from public.hotspots where slug = $dyk$st-pauls-cathedral$dyk$), $dyk$During the Blitz, volunteer fire watchers slept on the cathedral roof to extinguish incendiary bombs.$dyk$, 2),
  ((select id from public.hotspots where slug = $dyk$st-pauls-cathedral$dyk$), $dyk$Wren's tombstone bears the inscription 'Si monumentum requiris, circumspice' – 'If you seek his monument, look around you.'$dyk$, 3);

delete from public.hotspot_facts where hotspot_id = (select id from public.hotspots where slug = $dyk$rosetta-stone-british-museum$dyk$);
insert into public.hotspot_facts (hotspot_id, text, sort_order)
values
  ((select id from public.hotspots where slug = $dyk$rosetta-stone-british-museum$dyk$), $dyk$The same text appears three times on the stone: in hieroglyphs, Demotic script and Greek.$dyk$, 0),
  ((select id from public.hotspots where slug = $dyk$rosetta-stone-british-museum$dyk$), $dyk$The French found the stone in 1799 – but the British took it as spoils of war after Napoleon's defeat.$dyk$, 1),
  ((select id from public.hotspots where slug = $dyk$rosetta-stone-british-museum$dyk$), $dyk$Champollion reportedly cried 'Je tiens l'affaire!' ('I've got it!') and fainted when he cracked the code in 1822.$dyk$, 2),
  ((select id from public.hotspots where slug = $dyk$rosetta-stone-british-museum$dyk$), $dyk$The Rosetta Stone is the British Museum's most visited object – the museum welcomes over six million visitors a year.$dyk$, 3),
  ((select id from public.hotspots where slug = $dyk$rosetta-stone-british-museum$dyk$), $dyk$During the First World War the stone was hidden in an Underground station to protect it from bombs.$dyk$, 4);

delete from public.hotspot_facts where hotspot_id = (select id from public.hotspots where slug = $dyk$nelsons-column$dyk$);
insert into public.hotspot_facts (hotspot_id, text, sort_order)
values
  ((select id from public.hotspots where slug = $dyk$nelsons-column$dyk$), $dyk$Nelson had already lost an eye and an arm in earlier battles when he died at Trafalgar in 1805.$dyk$, 0),
  ((select id from public.hotspots where slug = $dyk$nelsons-column$dyk$), $dyk$Sculptor Edwin Landseer used a dead lion from London Zoo as his model – it began to decompose before he finished.$dyk$, 1),
  ((select id from public.hotspots where slug = $dyk$nelsons-column$dyk$), $dyk$The lions' backs are anatomically wrong – concave like a dog's rather than straight.$dyk$, 2),
  ((select id from public.hotspots where slug = $dyk$nelsons-column$dyk$), $dyk$Hitler reportedly planned to dismantle the column and move it to Berlin after a successful invasion.$dyk$, 3);

delete from public.hotspot_facts where hotspot_id = (select id from public.hotspots where slug = $dyk$st-jamess-park$dyk$);
insert into public.hotspot_facts (hotspot_id, text, sort_order)
values
  ((select id from public.hotspots where slug = $dyk$st-jamess-park$dyk$), $dyk$Pelicans have lived in the park since 1664 – a gift from the Russian ambassador.$dyk$, 0),
  ((select id from public.hotspots where slug = $dyk$st-jamess-park$dyk$), $dyk$One of the park's pelicans became notorious in 2006 when it swallowed a live pigeon in front of shocked tourists.$dyk$, 1),
  ((select id from public.hotspots where slug = $dyk$st-jamess-park$dyk$), $dyk$James I kept crocodiles and camels here in the 17th century.$dyk$, 2),
  ((select id from public.hotspots where slug = $dyk$st-jamess-park$dyk$), $dyk$The park is surrounded by three palaces – Buckingham Palace, St James's Palace and Westminster.$dyk$, 3);

delete from public.hotspot_facts where hotspot_id = (select id from public.hotspots where slug = $dyk$tate-modern$dyk$);
insert into public.hotspot_facts (hotspot_id, text, sort_order)
values
  ((select id from public.hotspots where slug = $dyk$tate-modern$dyk$), $dyk$Architect Giles Gilbert Scott designed both the power station and Britain's classic red telephone box.$dyk$, 0),
  ((select id from public.hotspots where slug = $dyk$tate-modern$dyk$), $dyk$The Turbine Hall is 35 metres high – Olafur Eliasson's artificial sun here drew over two million visitors in 2003.$dyk$, 1),
  ((select id from public.hotspots where slug = $dyk$tate-modern$dyk$), $dyk$The chimney was deliberately built lower than the dome of St Paul's across the river – out of respect.$dyk$, 2),
  ((select id from public.hotspots where slug = $dyk$tate-modern$dyk$), $dyk$Entry to the collections is free, as at most major museums in London.$dyk$, 3);

delete from public.hotspot_facts where hotspot_id = (select id from public.hotspots where slug = $dyk$covent-garden$dyk$);
insert into public.hotspot_facts (hotspot_id, text, sort_order)
values
  ((select id from public.hotspots where slug = $dyk$covent-garden$dyk$), $dyk$Samuel Pepys watched England's first recorded Punch and Judy show here in 1662.$dyk$, 0),
  ((select id from public.hotspots where slug = $dyk$covent-garden$dyk$), $dyk$Street performers must pass an audition to perform on the piazza.$dyk$, 1),
  ((select id from public.hotspots where slug = $dyk$covent-garden$dyk$), $dyk$The name comes from 'convent garden' – Westminster Abbey's kitchen garden stood here in the Middle Ages.$dyk$, 2),
  ((select id from public.hotspots where slug = $dyk$covent-garden$dyk$), $dyk$My Fair Lady's Eliza Doolittle was a flower girl right here at Covent Garden market.$dyk$, 3);

delete from public.hotspot_facts where hotspot_id = (select id from public.hotspots where slug = $dyk$abbey-road-crossing$dyk$);
insert into public.hotspot_facts (hotspot_id, text, sort_order)
values
  ((select id from public.hotspots where slug = $dyk$abbey-road-crossing$dyk$), $dyk$The entire photo shoot took ten minutes – the photographer stood on a stepladder while a policeman stopped the traffic.$dyk$, 0),
  ((select id from public.hotspots where slug = $dyk$abbey-road-crossing$dyk$), $dyk$Paul McCartney is barefoot on the cover – which fuelled the myth that he had secretly died.$dyk$, 1),
  ((select id from public.hotspots where slug = $dyk$abbey-road-crossing$dyk$), $dyk$The crossing was granted Grade II listed heritage status in 2010.$dyk$, 2),
  ((select id from public.hotspots where slug = $dyk$abbey-road-crossing$dyk$), $dyk$The wall outside the studio is repainted regularly – it constantly fills up with fans' graffiti.$dyk$, 3),
  ((select id from public.hotspots where slug = $dyk$abbey-road-crossing$dyk$), $dyk$A webcam streams the crossing live around the clock – wave to the world!$dyk$, 4);

delete from public.hotspot_facts where hotspot_id = (select id from public.hotspots where slug = $dyk$platform-nine-and-three-quarters$dyk$);
insert into public.hotspot_facts (hotspot_id, text, sort_order)
values
  ((select id from public.hotspots where slug = $dyk$platform-nine-and-three-quarters$dyk$), $dyk$Rowling has admitted she mixed up King's Cross with Euston – the wall she described doesn't actually exist here.$dyk$, 0),
  ((select id from public.hotspots where slug = $dyk$platform-nine-and-three-quarters$dyk$), $dyk$The film scenes were shot at platforms 4 and 5, not 9 and 10.$dyk$, 1),
  ((select id from public.hotspots where slug = $dyk$platform-nine-and-three-quarters$dyk$), $dyk$Half a luggage trolley is mounted in the wall – as if it's on its way to Hogwarts.$dyk$, 2),
  ((select id from public.hotspots where slug = $dyk$platform-nine-and-three-quarters$dyk$), $dyk$Rowling's parents met on a train departing from King's Cross station.$dyk$, 3);

delete from public.hotspot_facts where hotspot_id = (select id from public.hotspots where slug = $dyk$trafalgar-square-police-box$dyk$);
insert into public.hotspot_facts (hotspot_id, text, sort_order)
values
  ((select id from public.hotspots where slug = $dyk$trafalgar-square-police-box$dyk$), $dyk$The station held a single police officer – and in emergencies, two very cramped prisoners.$dyk$, 0),
  ((select id from public.hotspots where slug = $dyk$trafalgar-square-police-box$dyk$), $dyk$When the telephone receiver was lifted, the lamp on top flashed to summon backup.$dyk$, 1),
  ((select id from public.hotspots where slug = $dyk$trafalgar-square-police-box$dyk$), $dyk$Today it serves as a broom cupboard for Westminster Council cleaners.$dyk$, 2),
  ((select id from public.hotspots where slug = $dyk$trafalgar-square-police-box$dyk$), $dyk$It was built in 1926 to discreetly monitor demonstrations on the square – the public had objected to a visible police box.$dyk$, 3);

delete from public.hotspot_facts where hotspot_id = (select id from public.hotspots where slug = $dyk$london-stone$dyk$);
insert into public.hotspot_facts (hotspot_id, text, sort_order)
values
  ((select id from public.hotspots where slug = $dyk$london-stone$dyk$), $dyk$According to legend, London falls if the stone is destroyed: 'So long as the Stone of Brutus is safe, so long shall London flourish.'$dyk$, 0),
  ((select id from public.hotspots where slug = $dyk$london-stone$dyk$), $dyk$Rebel leader Jack Cade struck the stone with his sword in 1450 and declared himself lord of London – the scene appears in Shakespeare.$dyk$, 1),
  ((select id from public.hotspots where slug = $dyk$london-stone$dyk$), $dyk$Nobody knows what the stone originally was – a Roman milestone, a druidic altar and a magical guardian stone have all been proposed.$dyk$, 2),
  ((select id from public.hotspots where slug = $dyk$london-stone$dyk$), $dyk$The stone has survived both the Great Fire of 1666 and the bombing raids of the Second World War.$dyk$, 3);

delete from public.hotspot_facts where hotspot_id = (select id from public.hotspots where slug = $dyk$fifty-berkeley-square$dyk$);
insert into public.hotspot_facts (hotspot_id, text, sort_order)
values
  ((select id from public.hotspots where slug = $dyk$fifty-berkeley-square$dyk$), $dyk$Prime Minister George Canning lived in the house until his death in 1827.$dyk$, 0),
  ((select id from public.hotspots where slug = $dyk$fifty-berkeley-square$dyk$), $dyk$In the 1887 legend, two sailors spent the night in the attic room – one fled, the other was found dead on the railings outside.$dyk$, 1),
  ((select id from public.hotspots where slug = $dyk$fifty-berkeley-square$dyk$), $dyk$The ghost is said to appear as a brown mist that frightens onlookers out of their wits.$dyk$, 2),
  ((select id from public.hotspots where slug = $dyk$fifty-berkeley-square$dyk$), $dyk$The recluse Thomas Myers, who lived here alone in the 1860s, is thought to have sparked the ghost rumours.$dyk$, 3),
  ((select id from public.hotspots where slug = $dyk$fifty-berkeley-square$dyk$), $dyk$No hauntings have been reported since a bookshop took over the house in the 1930s.$dyk$, 4);

delete from public.hotspot_facts where hotspot_id = (select id from public.hotspots where slug = $dyk$sweeney-todd-fleet-street$dyk$);
insert into public.hotspot_facts (hotspot_id, text, sort_order)
values
  ((select id from public.hotspots where slug = $dyk$sweeney-todd-fleet-street$dyk$), $dyk$Sweeney Todd probably never existed – the story comes from the serial 'The String of Pearls', published 1846–47.$dyk$, 0),
  ((select id from public.hotspots where slug = $dyk$sweeney-todd-fleet-street$dyk$), $dyk$According to legend, the victims became the filling in Mrs Lovett's popular meat pies.$dyk$, 1),
  ((select id from public.hotspots where slug = $dyk$sweeney-todd-fleet-street$dyk$), $dyk$The barber's chair stood over a trapdoor – one flick of a lever and the customer plunged into the cellar.$dyk$, 2),
  ((select id from public.hotspots where slug = $dyk$sweeney-todd-fleet-street$dyk$), $dyk$The legend became both a Sondheim musical (1979) and a Tim Burton film starring Johnny Depp (2007).$dyk$, 3);

