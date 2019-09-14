program poker_bot;
uses graph, wincrt;
const deckLen = 52;

type Tcard = record
               suit, value: byte;
             end;
     Tdeck = array[1..52] of Tcard;
     Thand = array[1..7] of Tcard;
     ThandInfo = array[1..11] of boolean;
     TfreqVal = array[2..14] of byte;
     TfreqSuit = array[1..4] of byte;
     Tbutton = record
                  barColor, textColor: byte;
                  text: string;
               end;

var deck: Tdeck;
    handInfo: ThandInfo;
    i, j: byte;
    gm, gd: smallint;
    maxX, maxY, cardWidth, cardHeight, xOptions, yOptions, optionWidth, optionHeight, blind: integer;
    stack: longint;
    play: boolean;


function maxVal(p: TfreqVal): byte;
var i, temporaryMax: byte;
begin
  temporaryMax:= p[2];
  FOR i:= 3 to 14 do
      IF p[i]>temporaryMax THEN
         temporaryMax:= p[i];
  maxVal:= temporaryMax;
end;

function maxSuit(p: TfreqSuit): byte;
var i, temporaryMax: byte;
begin
  temporaryMax:= p[1];
  FOR i:= 2 to 4 do
      IF p[i]>temporaryMax THEN
         temporaryMax:= p[i];
  maxSuit:= temporaryMax;
end;

function max(a, b: byte): byte;
begin
  IF a>b THEN max:= a
  ELSE max:= b;
end;

function min(a, b: byte): byte;
begin
  IF a<b THEN min:= a
  ELSE min:= b;
end;

function index(p: TfreqVal; x: byte; var count: byte): byte;
var temporaryIndex, i: byte;
    found: boolean;

begin
  temporaryIndex:= 0;
  found:= false;
  count:= 0;
  FOR i:= 2 to 14 do
      IF x=p[i] THEN begin
         count:= count+1;
         IF not found THEN begin
            temporaryIndex:= i;
            found:= true;
         end;
      end;
  index:= temporaryIndex;
end;

function cut(hand: Thand; startIndex: byte = 1; endIndex: byte = 5): Thand;
var cutHand: Thand;
    i, j: byte;

begin
  {neviem ako prelozit flop, turn, river.. tak uz rovno vsetko dam po anglicky}
  j:= 0;
  FOR i:= startIndex to endIndex do begin
     j:= j+1;
     cutHand[j]:= hand[i];
  end;
  cut:= cutHand;
end;

function contains(hand: Thand; value, suit: byte): boolean;
var i: byte;
    found: boolean;

begin
  found:= false;
  FOR i:= 1 to 7 do
      IF (hand[i].value=value) and (hand[i].suit=suit) THEN found:= true;
  contains:= found;
end;

function findWinner(hand1, hand2: Thand): string;
var winner: string;
    winnerFound: boolean;
    j: byte;

begin
  winnerFound:= false;
  j:= 0;
  WHILE not winnerFound and (j<5) do begin
    j:= j+1;
    IF hand1[j].value>hand2[j].value THEN begin
       winner:= '1';
       winnerFound:= true;
    end
    ELSE IF hand1[j].value<hand2[j].value THEN begin
       winner:= '2';
       winnerFound:= true;
    end;
    IF not winnerFound THEN winner:= 'split';
  end;
  findWinner:= winner;

end;

function newDeck: Tdeck;
var deck: Tdeck;
    card, i, j: byte;
begin
  card:= 0;

  FOR i:= 1 to 4 do
      FOR j:= 2 to 14 do begin
          card:= card+1;
          deck[card].suit:= i;
          deck[card].value:= j;
      end;

  newDeck:= deck;
end;

function shuffledDeck(deck: Tdeck): Tdeck;
var i, index: byte;
    e: Tcard;

begin
  randomize;
  FOR i:= 1 to deckLen do begin
      index:= random(deckLen-i+1)+1;
      e:= deck[deckLen-i+1];
      deck[deckLen-i+1]:= deck[index];
      deck[index]:= e;
  end;
  shuffledDeck:= deck;

end;

function handSort(hand: Thand; var handInfo: ThandInfo): Thand;
var frequencyValues: array[2..14] of byte;
    frequencySuits: array[1..4] of byte;
    pairlessHand: array[1..7] of Tcard;
    flushColor: 1..4;
    highCard, pair, twoPair, threeOfKind, wheel, straight, flush, fullHouse, fourOfKind, wheelFlush, straightFlush, add: boolean;
    e, kicker: Tcard;
    wheelHand, theHand: Thand;
    i, j, wheelFlushCompletion, straightFlushCompletion, straightCompletion, handLen, pairlessHandLen,
    straightStartIndex, straightFlushStartIndex, mostSameCards, countOfPairs, countOfSets, x: byte;

begin

  FOR i:= 2 to 14 do frequencyValues[i]:= 0;
  FOR i:= 1 to 4 do frequencySuits[i]:= 0;

  handLen:= 0;
  WHILE (hand[handLen+1].value<>0) and (handLen<7) do begin {dlzka handy je premenliva (5-7).. zistim pocet vyskytov values a suits v hande a zaroven zistim hand length}
     handLen:= handLen+1;
     frequencyValues[hand[handLen].value]:= frequencyValues[hand[handLen].value]+1;
     frequencySuits[hand[handLen].suit]:= frequencySuits[hand[handLen].suit]+1;
  end;

  FOR i:= 1 to handLen do
      FOR j:= 1 to handLen-1 do begin {zoradenie prioritne podla vyskytov, sekundarne podla velkosti karty... 2 5 2 4 4 2 5 -> 2 2 2 5 5 4 4}
         IF frequencyValues[hand[j].value]<frequencyValues[hand[j+1].value] THEN begin
           e:= hand[j];
           hand[j]:= hand[j+1];
           hand[j+1]:= e;
         end
         ELSE IF (frequencyValues[hand[j].value]=frequencyValues[hand[j+1].value]) and (hand[j].value<hand[j+1].value) THEN begin
           e:= hand[j];
           hand[j]:= hand[j+1];
           hand[j+1]:= e;
         end;
      end;

  highCard:= false;
  pair:= false;
  twoPair:= false;
  threeOfKind:= false;
  wheel:= false; {postupka 5 4 3 2 A}
  straight:= false;
  IF maxSuit(frequencySuits)>=5 THEN begin
     flush:= true;
     FOR i:= 1 to 4 do
         IF frequencySuits[i]=maxSuit(frequencySuits) THEN flushColor:= i;
  end

  ELSE flush:= false;
  fullHouse:= false;
  fourOfKind:= false;
  wheelFlush:= false;
  straightFlush:= false;

  pairlessHandLen:= 0;
  FOR i:= 1 to handLen do begin
     add:= true;
     IF flush and (hand[i].suit<>flushColor) and (contains(hand, hand[i].value, flushColor)) THEN add:= false;
     FOR j:= 1 to pairlessHandLen do
         IF hand[i].value=pairlessHand[j].value THEN add:= false;
     IF add THEN begin
        pairlessHandLen:= pairlessHandLen+1;
        pairlessHand[pairLessHandLen]:= hand[i];
     end;
  end;

  IF pairlessHandLen>=5 THEN begin {analyza suspicious vtipnych straight, straightFlush hand..}
     IF (frequencyValues[5]>0) and (frequencyValues[4]>0) and (frequencyValues[3]>0) and (frequencyValues[2]>0) and (frequencyValues[14]>0) THEN
        IF flush THEN begin
          wheelFlushCompletion:= 0;
          FOR i:= 1 to handLen do begin
              IF (hand[i].value=5) and (hand[i].suit=flushColor) THEN wheelFlushCompletion:= wheelFlushCompletion+1
              ELSE IF (hand[i].value=4) and (hand[i].suit=flushColor) THEN wheelFlushCompletion:= wheelFlushCompletion+1
              ELSE IF (hand[i].value=3) and (hand[i].suit=flushColor) THEN wheelFlushCompletion:= wheelFlushCompletion+1
              ELSE IF (hand[i].value=2) and (hand[i].suit=flushColor) THEN wheelFlushCompletion:= wheelFlushCompletion+1
              ELSE IF (hand[i].value=14) and (hand[i].suit=flushColor) THEN wheelFlushCompletion:= wheelFlushCompletion+1;
          end;
          wheelFlush:= wheelFlushCompletion=5;
       end
       ELSE begin
          wheel:= true;
          FOR i:= 1 to pairlessHandLen do
              IF pairlessHand[i].value=5 THEN wheelHand[1]:= pairlessHand[i]
              ELSE IF pairlessHand[i].value=4 THEN wheelHand[2]:= pairlessHand[i]
              ELSE IF pairlessHand[i].value=3 THEN wheelHand[3]:= pairlessHand[i]
              ELSE IF pairlessHand[i].value=2 THEN wheelHand[4]:= pairlessHand[i]
              ELSE IF pairlessHand[i].value=14 THEN wheelHand[5]:= pairlessHand[i];
       end;
     FOR i:= 1 to pairlessHandLen do
         FOR j:= 1 to pairlessHandLen-1 do
             IF pairlessHand[i].value<pairlessHand[i+1].value THEN begin
                 e:= pairlessHand[i];
                 pairlessHand[i]:= pairlessHand[i+1];
                 pairlessHand[i+1]:= e;
             end;
     straightCompletion:= 1;
     straightFlushCompletion:= 1;
     FOR i:= 1 to pairlessHandLen-1 do begin
          IF (pairlessHand[i].value=pairlessHand[i+1].value+1) and (pairlessHand[i].suit=pairlessHand[i+1].suit) THEN straightFlushCompletion:= straightFlushCompletion+1
          ELSE straightFlushCompletion:= 1;

          IF pairlessHand[i].value=pairlessHand[i+1].value+1 THEN straightCompletion:= straightCompletion+1
          ELSE straightCompletion:= 1;

          IF straightFlushCompletion=5 THEN begin
             straightFlush:= true;
             straightFlushStartIndex:= i-3;
          end
          ELSE IF straightCompletion=5 THEN begin
             straight:= true;
             straightStartIndex:= i-3;
          end;
     end;
  end; {end sekcie pre analyzu suspicious vtipnych straight, straightFlush, wheel... hand}

  mostSameCards:= maxVal(frequencyValues);
  index(frequencyValues, 2, countOfPairs);
  index(frequencyValues, 3, countOfSets);

  IF straightFlush THEN begin {ideme konkretne urcit co to za material drzime na ruke.. vsetko potrebne uz mame zistene (dufam)}
     theHand:= cut(pairlessHand, straightFlushStartIndex, straightFlushStartIndex+4);
  end

  ELSE IF wheelFlush THEN begin
     theHand[1].value:= 5; theHand[1].suit:= flushColor;
     theHand[2].value:= 4; theHand[2].suit:= flushColor;
     theHand[3].value:= 3; theHand[3].suit:= flushColor;
     theHand[4].value:= 2; theHand[4].suit:= flushColor;
     theHand[5].value:= 14; theHand[5].suit:= flushColor;
  end

  ELSE IF mostSameCards=4 THEN begin
     fourOfKind:= true;
     kicker:= hand[5];
     FOR i:= 6 to handLen do
         IF hand[i].value>kicker.value THEN kicker:= hand[i];
     theHand:= cut(hand, 1, 4);
     theHand[5]:= kicker;
  end

  ELSE IF (mostSameCards=3) and ((countOfPairs>0) or (countOfSets>1)) THEN begin
     fullHouse:= true;
     theHand:= cut(hand);
  end

  ELSE IF flush THEN begin
     j:= 0;
     FOR i:=1 to pairlessHandLen do
         IF (pairlessHand[i].suit=flushColor) and (j<5) THEN begin
            j:= j+1;
            theHand[j]:= pairlessHand[i];
         end;
  end

  ELSE IF straight THEN
     theHand:= cut(pairlessHand, straightStartIndex, straightStartIndex+4)

  ELSE IF wheel THEN
     theHand:= wheelHand

  ELSE IF mostSameCards=3 THEN begin
     threeOfKind:= true;
     theHand:= cut(hand);
  end

  ELSE IF (mostSameCards=2) and (countOfPairs>1) THEN begin {handa moze mat aj tri pary.. 77 66 55 A 2.. aj ked su tam dve patky, teraz chceme ako kicker to eso, takze..}
     twoPair:= true;
     kicker:= hand[5];
     FOR i:= 6 to handLen do
         IF hand[i].value>kicker.value THEN kicker:= hand[i];
     theHand:= cut(hand, 1, 4);
     theHand[5]:= kicker;
  end

  ELSE IF mostSameCards=2 THEN begin
     pair:= true;
     theHand:= cut(hand);
  end
  ELSE begin
     highCard:= true;
     theHand:= cut(hand);
  end;

  handInfo[1]:= straightFlush; handInfo[2]:= wheelFlush; handInfo[3]:= fourOfKind; handInfo[4]:= fullHouse; handInfo[5]:= flush; handInfo[6]:= straight;
  handInfo[7]:= wheel; handInfo[8]:= threeOfKind; handInfo[9]:= twoPair; handInfo[10]:= pair; handInfo[11]:= highCard;
  theHand[6].value:= 0; theHand[6].suit:= 0; theHand[7].value:= 0; theHand[7].suit:= 0;

  handSort:= theHand;

end;

function handComparison(hand1, hand2: Thand; handInfo1, handInfo2: ThandInfo): string;
var winner: string;

begin
  IF handInfo1[1] or handInfo2[1] THEN
     IF handInfo1[1] and not handInfo2[1] THEN winner:= '1'
     ELSE IF not handInfo1[1] and handInfo2[1] THEN winner:= '2'
     ELSE winner:= findWinner(hand1, hand2)

  ELSE IF handInfo1[2] or handInfo2[2] THEN
     IF handInfo1[2] and not handInfo2[12] THEN winner:= '1'
     ELSE IF not handInfo1[2] and handInfo2[2] THEN winner:= '2'
     ELSE winner:= 'split'

  ELSE IF handInfo1[3] or handInfo2[3] THEN
     IF handInfo1[3] and not handInfo2[3] THEN winner:= '1'
     ELSE IF not handInfo1[3] and handInfo2[3] THEN winner:= '2'
     ELSE winner:= findWinner(hand1, hand2)

  ELSE IF handInfo1[4] or handInfo2[4] THEN
     IF handInfo1[4] and not handInfo2[4] THEN winner:= '1'
     ELSE IF not handInfo1[4] and handInfo2[4] THEN winner:= '2'
     ELSE winner:= findWinner(hand1, hand2)

  ELSE IF handInfo1[5] or handInfo2[5] THEN
     IF handInfo1[5] and not handInfo2[5] THEN winner:= '1'
     ELSE IF not handInfo1[5] and handInfo2[5] THEN winner:= '2'
     ELSE winner:= findWinner(hand1, hand2)

  ELSE IF handInfo1[6] or handInfo2[6] THEN
     IF handInfo1[6] and not handInfo2[6] THEN winner:= '1'
     ELSE IF not handInfo1[6] and handInfo2[6] THEN winner:= '2'
     ELSE
        IF hand1[1].value>hand2[1].value THEN winner:= '1'
        ELSE IF hand1[1].value<hand2[1].value THEN winner:= '2'
        ELSE winner:= 'split'

  ELSE IF handInfo1[7] or handInfo2[7] THEN
     IF handInfo1[7] and not handInfo2[7] THEN winner:= '1'
     ELSE IF not handInfo1[7] and handInfo2[7] THEN winner:= '2'
     ELSE winner:= 'split'

  ELSE IF handInfo1[8] or handInfo2[8] THEN
     IF handInfo1[8] and not handInfo2[8] THEN winner:= '1'
     ELSE IF not handInfo1[8] and handInfo2[8] THEN winner:= '2'
     ELSE winner:= findWinner(hand1, hand2)

  ELSE IF handInfo1[9] or handInfo2[9] THEN
     IF handInfo1[9] and not handInfo2[9] THEN winner:= '1'
     ELSE IF not handInfo1[9] and handInfo2[9] THEN winner:= '2'
     ELSE winner:= findWinner(hand1, hand2)

  ELSE IF handInfo1[10] or handInfo2[10] THEN
     IF handInfo1[10] and not handInfo2[10] THEN winner:= '1'
     ELSE IF not handInfo1[10] and handInfo2[10] THEN winner:= '2'
     ELSE winner:= findWinner(hand1, hand2)

  ELSE winner:= findWinner(hand1, hand2);

  handComparison:= winner;
end;

function handAnalysis(fullHand: Thand; handInfo: ThandInfo; board, hand: Thand; boardLen: byte): real;
var wonHands, allHands: integer;
    i, j: byte;
    deck: Tdeck;
    winner: string;
    hand2: Thand;
    handInfo2: ThandInfo;

begin
  wonHands:= 0;
  allHands:= 0;
  deck:= newDeck;
  FOR i:= 1 to deckLen do begin
      IF contains(hand, deck[i].value, deck[i].suit) or contains(board, deck[i].value, deck[i].suit) THEN continue;
      board[boardLen+1]:= deck[i];
      FOR j:= i+1 to deckLen do begin
          IF contains(hand, deck[j].value, deck[j].suit) or contains(board, deck[j].value, deck[j].suit) THEN continue;
          board[boardLen+2]:= deck[j];
          hand2:= handSort(board, handInfo2);
          winner:= handComparison(fullHand, hand2, handInfo, handInfo2);
          IF winner='1' THEN wonHands:= wonHands+1;
          IF winner<>'split' THEN allHands:= allHands+1;
      end;
  end;

  handAnalysis:= wonHands/allHands;

end;

function preflopAnalysis(hand: Thand): real;
var opponent: Thand;
    deck: Tdeck;
    wonHands, allHands: integer;
    i, j: byte;

begin
  wonHands:= 0; {not really won, len lepsie, ale nech sa to podoba na handAnalysis}
  allHands:= 0;
  deck:= newDeck;
  FOR i:= 1 to deckLen do begin
      IF contains(hand, deck[i].value, deck[i].suit) THEN continue;
      opponent[1]:= deck[i];
      FOR j:= i+1 to deckLen do begin
          IF contains(hand, deck[j].value, deck[j].suit) THEN continue;
          opponent[2]:= deck[j];
          IF (hand[1].value=hand[2].value) and (not (opponent[1].value=opponent[2].value) or (hand[1].value>opponent[1].value)) THEN wonHands:= wonHands+1
          ELSE IF not (opponent[1].value=opponent[2].value) THEN
               IF max(hand[1].value, hand[2].value)>max(opponent[1].value, opponent[2].value) THEN wonHands:= wonHands+1
               ELSE IF max(hand[1].value, hand[2].value)=max(opponent[1].value, opponent[2].value) THEN
                  IF min(hand[1].value, hand[2].value)>min(opponent[1].value, opponent[2].value) THEN wonHands:= wonHands+1
                  ELSE IF min(hand[1].value, hand[2].value)=min(opponent[1].value, opponent[2].value) THEN continue;
          allHands:= allHands+1;
      end;
  end;
  preflopAnalysis:= wonHands/allHands;
end;

procedure handDrawAnalysis(fullHand, hand, board: Thand; handInfo1: ThandInfo; situation: string; var chanceToHit, drawingHandWorth: real);
{tuto proceduru asi nepouzijem.. nemozem povedat ze by robila to co ma a nemozem povedat ze by nerobila to co ma ale hlavne nemozem povedat ze by robila to co ma}
{mala zistit aka je sanca ze sa nam zlepsi handa a okolko, aj to viac menej robi ale su tu nejake bugy a moja motivacia<dovod najst chybu takze..}

const betterHandMinWorth = 0.85;
var potentialHand: Thand;
    potentialHandRate, fullHandRate, potentialHandWorth: real;
    wonHands, allHands: integer;
    handInfo2: ThandInfo;

begin
  deck:= newDeck;
  potentialHand:= fullHand;
  potentialHandRate:= 0;
  wonHands:= 0;
  allHands:= 0;
  IF situation='flop' THEN begin
     fullHandRate:= handAnalysis(fullHand, handInfo1, board, hand, 3);
     FOR i:= 1 to deckLen do begin
         IF contains(fullHand, deck[i].value, deck[i].suit) THEN continue; {alebo if not, ale takto sa citim ako profesionalny pan programator ked pouzivam prikazy ktore zbytocne manipuluju beh programu.. mozno to neskor prepisem, ale asi ne}
         potentialHand[6]:= deck[i];
         FOR j:= i+1 to deckLen do begin
            IF contains(fullHand, deck[j].value, deck[j].suit) THEN continue;
            potentialHand[7]:= deck[j];
            potentialHand:= handSort(potentialHand, handInfo2);
            potentialHandRate:= handAnalysis(potentialHand, handInfo2, board, hand, 3);
            IF (potentialHandRate>betterHandMinWorth) and (potentialHandRate>fullHandRate) THEN begin {tak kedze som tejto procedurke nedal uvod a je celkom dolezita.. zistujem ci botovi moze nieco dojst, co by mu zlepsilo handu nad nejaku uroven (const BetterHandMinWorth - flush, postupka, ..), takze simulujem co vsetko moze dojst a ako to ovplyvni jeho handu}
                wonHands:= wonHands+1; {znovu.. not really won, len better, ale vsade mam tuto dvojicu wonHands-allHands tak naco to menit len kvoli tomu ze jedna premenna znamena nieco uplne ine.. sarkazmus not intended}
                potentialHandWorth:= potentialHandWorth+potentialHandRate;
            end;
            allHands:= allHands+1;
         end;
     end;
  end
  ELSE IF situation='turn' THEN
     FOR i:= 1 to deckLen do begin {turn.. uz len jedna karta moze prist}
         IF contains(potentialHand, deck[i].value, deck[i].suit) THEN continue;
         potentialHand[7]:= deck[i];
         potentialHand:= handSort(potentialHand, handInfo2);
         IF handComparison(fullHand, potentialHand, handInfo1, handInfo2)='2' THEN begin
            wonHands:= wonHands+1;
            potentialHandRate:= potentialHandRate+handAnalysis(potentialHand, handInfo2, board, hand, 4);
         end;
         allHands:= allHands+1;
     end;

  IF allHands>0 THEN chanceToHit:= wonHands/allHands
  ELSE chanceToHit:= 0;
  IF wonHands>0 THEN drawingHandWorth:= potentialHandWorth/wonHands {aritmeticky priemer.. velmi som chcel pouzit geometricky, len tak, pre tu srandu.. ale nejde tu spravit n ta odmocnica.. to by som musel asi pouzit niaku rovnicovu metodu.. nejakym sposobom sa priblizovat k x-ku ale zas az tak geometricky priemer nechcem}
  ELSE drawingHandWorth:= 0;

end;

procedure drawPlayer;
begin
  setcolor(9);
  moveTo(round(maxX*0.13), round(maxY*0.84));   {lebo argument lineThickness v setlinestyle berie "az" dva parametre.. tenka a tensia}
  lineTo(round(maxX*0.07), round(maxY*0.73));
  lineTo(round(maxX*0.075), round(maxY*0.72));
  lineTo(round(maxX*0.135), round(maxY*0.84));
  lineTo(round(maxX*0.13), round(maxY*0.84));
  setfillstyle(1, 9);
  floodFill(round(maxX*0.132), round(maxY*0.835), 9);

  {setcolor(7);
  moveTo(round(maxX*0.13), round(maxY*0.84));  {ruky na stole..}
  lineTo(round(maxX*0.17), round(maxY*0.7));
  lineTo(round(maxX*0.175), round(maxY*0.67));
  lineTo(round(maxX*0.18), round(maxY*0.7));
  lineTo(round(maxX*0.185), round(maxY*0.67));
  lineTo(round(maxX*0.19), round(maxY*0.7));
  lineTo(round(maxX*0.13), round(maxY*0.84));  }

  setfillstyle(1, 14);
  fillellipse(round(maxX*0.13), round(maxY*0.87), round(maxX*0.1), round(maxY*0.1));
  setcolor(15);
  ellipse(round(maxX*0.13), round(maxY*0.87), 0, 360, round(maxX*0.05), round(maxY*0.05));
  ellipse(round(maxX*0.13), round(maxY*0.87), 0, 360, round(maxX*0.06), round(maxY*0.06));
  setfillstyle(1, 15);
  floodfill(round(maxX*0.185), round(maxY*0.87), 15);

  setcolor(4);
  setfillstyle(1, 10);
  fillellipse(round(maxX*0.06), round(maxY*0.7), round(maxX*0.02), round(maxY*0.02));
  setfillstyle(1, 3);
  fillellipse(round(maxX*0.04), round(maxY*0.68), round(maxX*0.02), round(maxY*0.02));
  setfillstyle(1, 12);
  fillellipse(round(maxX*0.02), round(maxY*0.66), round(maxX*0.02), round(maxY*0.02));
end;

procedure drawBot;

begin
  setfillstyle(1, 3);
  setcolor(5);
  moveTo(round(maxX*0.8), round(maxY*0.08));
  lineTo(round(maxX*0.8), round(maxY*0.2));
  lineTo(round(maxX*0.95), round(maxY*0.2));
  lineTo(round(maxX*0.98), round(maxY*0.17));
  lineTo(round(maxX*0.98), round(maxY*0.05));        {"hlava"}
  lineTo(round(maxX*0.83), round(maxY*0.05));
  lineTo(round(maxX*0.8), round(maxY*0.08));
  floodfill(round(maxX*0.96), round(maxY*0.06), 5);
  moveTo(round(maxX*0.95), round(maxY*0.08));
  lineTo(round(maxX*0.98), round(maxY*0.05));
  moveTo(round(maxX*0.8), round(maxY*0.08));
  lineTo(round(maxX*0.95), round(maxY*0.08));
  lineTo(round(maxX*0.95), round(maxY*0.2));

  moveTo(round(maxX*0.88), round(maxY*0.2));
  lineTo(round(maxX*0.88), round(maxY*0.3));
  lineTo(round(maxX*0.91), round(maxY*0.34));      {niake divne neidentifikovatelne nieco}
  lineTo(round(maxX), round(maxY*0.34));
  moveTo(round(maxX*0.92), round(maxY*0.2));
  lineTo(round(maxX*0.92), round(maxY*0.275));
  lineTo(round(maxX*0.94), round(maxY*0.29));
  lineTo(round(maxX), round(maxY*0.3));
  floodfill(round(maxX*0.9), round(maxY*0.25), 5);
  moveTo(round(maxX*0.91), round(maxY*0.2));
  lineTo(round(maxX*0.91), round(maxY*0.28));
  lineTo(round(maxX*0.93), round(maxY*0.3));
  lineTo(round(maxX), round(maxY*0.3));

  setfillstyle(1, 4);
  setcolor(3);
  fillellipse(round(maxX*0.85), round(maxY*0.11), round(maxX*0.02), round(maxY*0.02));
  fillellipse(round(maxX*0.9), round(maxY*0.11), round(maxX*0.02), round(maxY*0.02));
  setlinestyle(solidln, 0, thickwidth);
  setcolor(4);
  moveTo(round(maxX*0.8), round(maxY*0.08));
  lineTo(round(maxX*0.83), round(maxY*0.11));
  lineTo(round(maxX*0.92), round(maxY*0.11));
  lineTo(round(maxX*0.95), round(maxY*0.08));
  moveTo(round(maxX*0.87), round(maxY*0.17));
  lineTo(round(maxX*0.82), round(maxY*0.17));
  lineTo(round(maxX*0.84), round(maxY*0.15));
  settextstyle(1, 0, 1);
  settextjustify(centertext, centertext);
  setcolor(6);
  outtextxy(round(maxX*0.85), round(maxY*0.11), '001101'); {13 - M}
  outtextxy(round(maxX*0.9), round(maxY*0.11), '010010'); {18 - K.. inspiroval som sa enigmou.. takato sifra to nie je len tak}
end;

procedure menu(var play: boolean);
const numOfOptions = 4;
      xOptions = 600;
      yOptions = 300;
      optionWidth = 400;
      optionHeight = 60;

var   ch: char;
      i, position, err, err2: byte;
      y: integer;
      button: array[1..4] of Tbutton;
      stackString, blindString: string;
      rewriting: boolean;

begin
  setBKcolor(7);
  cleardevice;

  drawBot;
  drawPlayer;

  settextstyle(1, 0, 10);
  setcolor(6);
  outtextxy(round(maxx*0.4), round(maxy*0.25),'P O K E R');

  settextstyle(1, 0, 10);
  setcolor(4);
  outtextxy(round(maxx*0.85), round(maxy*0.5),'B O T');

  settextstyle(1, 0, 3);
  settextjustify(1, 1);

  button[1].text:= 'HRA';
  button[4].text:= 'KONIEC';
  position:= 1;
  str(stack, stackString);
  str(blind, blindString);
  play:= false;
  ch:= ' ';

  REPEAT
    IF length(stackString)=0 THEN button[2].text:= 'STACK: 0'
    ELSE button[2].text:= 'STACK: '+stackString;
    IF length(blindString)=0 THEN button[3].text:= 'BLIND: 0'
    ELSE button[3].text:= 'BLIND: '+blindString;

    FOR i:= 1 to numOfOptions do begin
        button[i].barColor:= 5;
        button[i].textColor:= 2;
    end;

    button[position].barColor:= 2;
    button[position].textColor:= 5;
    y:= yOptions;

    FOR i:= 1 to numOfOptions do begin
        setfillstyle(1, button[i].barColor);
        bar(xOptions, y, xOptions+optionWidth, y+optionHeight);
        setcolor(button[i].textColor);
        outtextxy(xOptions+optionWidth div 2, y+optionHeight div 2, button[i].text);
        y:= y+2*optionHeight;
    end;


    REPEAT
      IF ch in ['0'..'9'] THEN rewriting:= false
      ELSE rewriting:= true;
      ch:= readkey;
    until (ch=#072) or (ch=#080) or (ch=#13) and ((position=1) or (position=4)) or ((ch in ['0'..'9']) or (ch=#8)) and ((position=3) or (position=2));

    IF ch=#072 THEN
       IF position>1 THEN position:= position-1
       ELSE position:= numOfOptions
    ELSE IF ch=#080 THEN
       IF position<numOfOptions THEN position:= position+1
       ELSE position:= 1                 {1->numOfOptions su obdlznicky tvariace sa ako tlacitka}

    ELSE IF (ch in ['0'..'9']) or (ch=#8) THEN begin
       IF position=2 THEN begin
           IF (length(stackString)>0) and (ch=#8) THEN delete(stackString, length(stackString), 1)
           ELSE IF (not rewriting) and (length(stackString)<=5) THEN stackString:= stackString+ch
           ELSE IF (length(stackString)>0) THEN stackString:= ch
       end

       ELSE IF position=3 THEN begin
           IF (length(blindString)>0) and (ch=#8) THEN delete(blindString, length(blindString), 1)
           ELSE IF (not rewriting) and (length(blindString)<=3) THEN blindString:= blindString+ch
           ELSE IF (length(stackString)>0) THEN blindString:= ch
       end
    end

    ELSE IF (ch=#13) and (position=1) THEN begin
       val(stackString, stack, err);
       val(blindString, blind, err2);
       IF (err>0) or (err2>0) or (stack<2*blind) THEN play:= false
       ELSE play:= true
    end;

  until (ch=#13) and (play or (position=4));

end;

procedure drawCard(x, y: integer; card: Tcard; turned: boolean);
const symbolConstant = 5;
var drawnValue: string;
    symbol: array[1..4] of PointType;

begin
  setlinestyle(solidln, 0, thickwidth);
  setcolor(1);
  rectangle(x, y, x+cardWidth, y+cardHeight);

  IF not turned THEN begin
     setfillstyle(xHatchFill, 6);
     setBKcolor(5);
     bar(x, y, x+cardWidth, y+cardHeight);
  end
  ELSE begin
    setfillstyle(1, 5);
    bar(x, y, x+cardWidth, y+cardHeight);
    IF card.suit=1 THEN begin  {clubs}
       setcolor(4);
       setfillstyle(1, 4);
       symbol[1].x:= x+round(cardWidth*0.5); symbol[1].y:= y+round(cardHeight*0.75);
       symbol[2].x:= x+round(cardWidth*0.6); symbol[2].y:= y+round(cardHeight*0.9);
       symbol[3].x:= x+round(cardWidth*0.4); symbol[3].y:= y+round(cardHeight*0.9);
       fillpoly(3, symbol);
       fillellipse(x+round(cardWidth*0.4), y+round(cardHeight*0.75), symbolConstant, symbolConstant);
       fillellipse(x+round(cardWidth*0.5), y+round(cardHeight*0.65), symbolConstant, symbolConstant);
       fillellipse(x+round(cardWidth*0.6), y+round(cardHeight*0.75), symbolConstant, symbolConstant);
    end
    ELSE IF card.suit=2 THEN begin   {diamonds}
       setcolor(6);
       setfillstyle(1, 6);
       symbol[1].x:= x+round(cardWidth*0.3); symbol[1].y:= y+round(cardHeight*0.8);
       symbol[2].x:= x+round(cardWidth*0.5); symbol[2].y:= y+round(cardHeight*0.7);
       symbol[3].x:= x+round(cardWidth*0.7); symbol[3].y:= y+round(cardHeight*0.8);
       symbol[4].x:= x+round(cardWidth*0.5); symbol[4].y:= y+round(cardHeight*0.9);
       fillpoly(4, symbol);

    end
    ELSE IF card.suit=3 THEN begin   {hearts}
       setcolor(6);
       setfillstyle(1, 6);
       fillellipse(x+round(cardWidth*0.4), y+round(cardHeight*0.75), symbolConstant, symbolConstant);
       fillellipse(x+round(cardWidth*0.6), y+round(cardHeight*0.75), symbolConstant, symbolConstant);
       moveTo(x+round(cardWidth*0.4)-symbolConstant, y+round(cardHeight*0.75));

       symbol[1].x:= x+round(cardWidth*0.5); symbol[1].y:= y+round(cardHeight*0.9);
       symbol[2].x:= x+round(cardWidth*0.6)+symbolConstant; symbol[2].y:= y+round(cardHeight*0.75);
       symbol[3].x:= x+round(cardWidth*0.4)-symbolConstant; symbol[3].y:= y+round(cardHeight*0.75);
       fillpoly(3, symbol);
    end
    ELSE begin   {spades}
       setcolor(4);
       setfillstyle(1, 4);
       fillellipse(x+round(cardWidth*0.4), y+round(cardHeight*0.75), round(0.7*symbolConstant), round(0.7*symbolConstant));
       fillellipse(x+round(cardWidth*0.6), y+round(cardHeight*0.75), round(0.7*symbolConstant), round(0.7*symbolConstant));
       moveTo(x+round(cardWidth*0.4)-symbolConstant, y+round(cardHeight*0.75));

       symbol[1].x:= x+round(cardWidth*0.5); symbol[1].y:= y+round(cardHeight*0.6);
       symbol[2].x:= x+round(cardWidth*0.6)+symbolConstant; symbol[2].y:= y+round(cardHeight*0.75);
       symbol[3].x:= x+round(cardWidth*0.4)-symbolConstant; symbol[3].y:= y+round(cardHeight*0.75);
       fillpoly(3, symbol);
       symbol[1].x:= x+round(cardWidth*0.5); symbol[1].y:= y+round(cardHeight*0.8);
       symbol[2].x:= x+round(cardWidth*0.6); symbol[2].y:= y+round(cardHeight*0.9);
       symbol[3].x:= x+round(cardWidth*0.4); symbol[3].y:= y+round(cardHeight*0.9);
       fillpoly(3, symbol);
    end;

    settextstyle(4, 0, 3);
    settextjustify(1, 0);
    IF card.value<=10 THEN str(card.value, drawnValue)
    ELSE
       CASE card.value of
         11: drawnValue:= 'J';
         12: drawnValue:= 'Q';
         13: drawnValue:= 'K';
         14: drawnValue:= 'A';
       end;
    outtextxy(x+cardWidth div 2, y+cardHeight div 2, drawnValue);
  end;

end;

procedure updateStackValue(x, y: integer; stack: longint; introString: string = '');
var stackString: string;

begin
  str(stack, stackString);
  stackString:= introString+stackString;
  setfillstyle(1, 1);
  setcolor(1);
  bar(x, y, x+round(maxx*0.13), y-round(maxy*0.05));
  settextstyle(1, 0, 2);
  settextjustify(lefttext, bottomtext);
  setcolor(4);
  IF stack>0 THEN outtextxy(x, y, stackString);
end;

procedure drawStack(x, y: integer; stack: longint; shift, chipRadius: integer; right: boolean);
var chipList: array[1..9] of byte;
    i, j, max: byte;
    printOut, stackString: string;
    y2, diverge, prepona: integer;
    obd: array[1..4] of PointType;

begin
   setlinestyle(1, 0, 1);
   str(stack, stackString);

   FOR i:= 1 to 9 do chipList[i]:= 0;
   diverge:= 0;

   WHILE stack>=1000000 do begin
       chipList[1]:= chipList[1]+1;
       stack:= stack-1000000;
   end;
   WHILE stack>=100000 do begin
       chipList[2]:= chipList[2]+1;
       stack:= stack-100000;
   end;
   WHILE stack>=10000 do begin
       chipList[3]:= chipList[3]+1;
       stack:= stack-10000;
   end;
   WHILE stack>=1000 do begin
       chipList[4]:= chipList[4]+1;
       stack:= stack-1000;
   end;
   WHILE stack>=100 do begin
       chipList[5]:= chipList[5]+1;
       stack:= stack-100;
   end;
   WHILE stack>=50 do begin
       chipList[6]:= chipList[6]+1;
       stack:= stack-50;
   end;
   WHILE stack>=25 do begin
       chipList[7]:= chipList[7]+1;
       stack:= stack-25;
   end;
   WHILE stack>=10 do begin
       chipList[8]:= chipList[8]+1;
       stack:= stack-10;
   end;
   WHILE stack>=1 do begin
       chipList[9]:= chipList[9]+1;
       stack:= stack-1;
   end;

   FOR i:= 1 to 9 do
       IF chipList[i]>9 THEN chipList[i]:= 9; {nebudem kreslit 200 chipov vysoku kopku kdesi mimo obrazovku.. pocet ma aj tak zaujima len pre vizualne purposes}
   IF right THEN begin
      obd[1].x:= x+chipRadius-1; obd[1].y:= y-round(4.5*chipRadius);
      obd[2].x:= x+chipRadius-1; obd[2].y:= y+round(1.8*chipRadius);
   end
   ELSE begin
      obd[1].x:= x-chipRadius+1; obd[1].y:= y-round(4.5*chipRadius);
      obd[2].x:= x-chipRadius+1; obd[2].y:= y+round(1.8*chipRadius);
   end;
   obd[3].x:= obd[2].x; obd[3].y:= obd[2].y;
   obd[4].x:= obd[1].x; obd[4].y:= obd[1].y;

   prepona:= round(sqrt(chipRadius*chipRadius*4+shift*shift)); {normalne ze pytagorova veta vyuzita.. aka sranda}
   FOR i:= 1 to 9 do begin
       IF right THEN begin
          obd[3].x:= obd[3].x+prepona;
          obd[3].y:= obd[3].y+shift;
          obd[4].x:= obd[4].x+prepona;
          obd[4].y:= obd[4].y+shift;
       end
       ELSE begin
          obd[3].x:= obd[3].x-prepona;
          obd[3].y:= obd[3].y-shift;
          obd[4].x:= obd[4].x-prepona;
          obd[4].y:= obd[4].y-shift;
       end;
   end;
   setfillstyle(1, 1);
   setlinestyle(1, 1, 2);
   setcolor(1);
   fillpoly(4, obd);


   FOR i:= 1 to 9 do begin
       IF chipList[i]>0 THEN begin
          IF right THEN x:= x+round(chipRadius*2)
          ELSE x:= x-round(chipRadius*2);
          CASE i of
             1: begin
                  setfillstyle(1, 4);
                  setcolor(5);
                  printOut:= '1M';
                end;
             2: begin
                  setfillstyle(1, 9);
                  setcolor(4);
                  printOut:= '100K';
                end;
             3: begin
                  setfillstyle(1, 2);
                  setcolor(5);
                  printOut:= '10K';
                end;
             4: begin
                  setfillstyle(1, 5);
                  setcolor(4);
                  printOut:= '1K';
                end;
             5: begin
                  setfillstyle(1, 8);
                  setcolor(5);
                  printOut:= '100';
                end;
             6: begin
                  setfillstyle(1, 11);
                  setcolor(4);
                  printOut:= '50';
                end;
             7: begin
                  setfillstyle(1, 13);
                  setcolor(5);
                  printOut:= '25';
                end;
             8: begin
                  setfillstyle(1, 6);
                  setcolor(4);
                  printOut:= '10';
                end;
             9: begin
                  setfillstyle(1, 7);
                  setcolor(5);
                  printOut:= '1';
                end;
          end;
          diverge:= diverge+shift;
          IF right THEN y2:= y+diverge
          ELSE y2:= y-diverge;

          FOR j:= 1 to chipList[i] do begin
              y2:= y2-round(chipRadius/4);
              fillellipse(x, y2, chipRadius, chipRadius);
          end;
          settextstyle(1, 0, 1);
          settextjustify(1, 1);
          outtextxy(x, y2, printOut);
       end;
   end;

end;

procedure botDecisionDisplay(s: string);
var triangle: array[1..3] of PointType;

begin
  setfillstyle(1, 5);
  setcolor(5);
  triangle[1].x:= round(maxx*0.77); triangle[1].y:= round(maxy*0.1);
  triangle[2].x:= round(maxx*0.79); triangle[2].y:= round(maxy*0.15);
  triangle[3].x:= round(maxx*0.75); triangle[3].y:= round(maxy*0.13);
  fillellipse(round(maxx*0.73), round(maxy*0.1), round(maxx*0.05), round(maxy*0.04));
  fillpoly(3, triangle);
  settextstyle(1, 0, 2);
  settextjustify(1, 1);
  setcolor(4);
  outtextxy(round(maxx*0.73), round(maxy*0.1), s);
  delay(1000);
  setfillstyle(1, 7);
  setcolor(7);
  fillellipse(round(maxx*0.73), round(maxy*0.1), round(maxx*0.05), round(maxy*0.04));
  fillpoly(3, triangle);
end;

procedure bet(playersTurn: boolean; betChips: longint; var plStack, botStack, sidePotPl, sidePotBot: longint);
begin
  IF playersTurn THEN begin
     sidePotPl:= sidePotPl+betChips;
     plStack:= plStack-betChips;
     drawStack(round(maxX*0.3), round(maxy*0.53), sidePotPl, 0, round(maxY*0.02), true); {x, y, divergencia v zvislom smere, polomer chipu, bool - smer (true - doprava)}
     updateStackValue(round(maxX*0.32), round(maxy*0.62), sidePotPl);
     drawStack(round(maxx*0.18), round(maxy*0.7), plStack, round(maxy*0.015), round(maxY*0.02), true);
     updateStackValue(round(maxX*0.17), round(maxy*0.64), plStack, 'Hrac: ');
  end
  ELSE begin
     sidePotBot:= sidePotBot+betChips;
     botStack:= botStack-betChips;
     drawStack(round(maxx*0.7), round(maxy*0.48), sidePotBot, 0, round(maxY*0.02), false);
     updateStackValue(round(maxX*0.65), round(maxy*0.57), sidePotBot);
     drawStack(round(maxx*0.82), round(maxy*0.34), botStack, round(maxy*0.015), round(maxY*0.02), false);
     updateStackValue(round(maxX*0.73), round(maxy*0.395), botStack, 'Bot: ');
  end;

end;

procedure decision(playersTurn: boolean; board, plHand, plFullHand, botHand, botFullHand: Thand; betFaced, plStack, botStack, sidePotPl, sidePotBot, pot: longint; blind: integer; var betOwn: longint; var folded: boolean);
var button: array[1..3] of Tbutton;
    y: integer;
    i, position, numOfOptions, choice: byte;
    minBet, toBetValue: longint;
    toBet, toCall, displayBet: string;
    ch: char;
    rewriting: boolean;
    handWorth, odds, agression: real;


begin
  folded:= false;
  IF playersTurn THEN begin
     position:= 1;
     setfillstyle(1, 1);
     bar(xOptions, yOptions, xOptions+optionWidth, yOptions+round(optionHeight*4.5));
     settextstyle(1, 0, 1);
     settextjustify(0, 0);

     IF betFaced=0 THEN begin
         numOfOptions:= 2;
         button[1].text:= 'CHECK';
         str(blind, toBet);
         minBet:= blind;
     end
     ELSE IF betFaced>=plStack THEN begin
         numOfOptions:= 2;
         str(betFaced, toCall);
         button[1].text:= 'CALL '+toCall;
         button[2].text:= 'FOLD';
     end
     ELSE IF betFaced>0 THEN begin
        numOfOptions:= 3;
        str(betFaced, toCall);
        button[1].text:= 'CALL '+toCall;
        button[3].text:= 'FOLD';
        str(2*sidePotBot, toBet);
        minBet:= (2*sidePotBot);
     end;

     REPEAT
       IF (betFaced>0) and (betFaced<plStack) THEN
          IF length(toBet)=0 THEN button[2].text:= 'RAISE 0'
          ELSE button[2].text:= 'RAISE '+toBet

       ELSE IF (betFaced=0) THEN
          IF length(toBet)=0 THEN button[2].text:= 'BET 0'
          ELSE button[2].text:= 'BET '+toBet;

       FOR i:= 1 to numOfOptions do begin
           button[i].barColor:= 5;
           button[i].textColor:= 2;
       end;
       button[position].barColor:= 2;
       button[position].textColor:= 5;
       y:= yOptions;

       FOR i:= 1 to numOfOptions do begin
           setfillstyle(1, button[i].barColor);
           bar(xOptions, y, xOptions+optionWidth, y+optionHeight);
           setcolor(button[i].textColor);
           outtextxy(xOptions+round(optionWidth*0.1), y+round(optionHeight*0.5), button[i].text);
           y:= y+round(1.5*optionHeight);
       end;

       REPEAT
         IF (position=2) and ((ch=#072) or (ch=#080)) THEN rewriting:= true
         ELSE rewriting:= false;
         ch:= readkey;
       until (ch=#072) or (ch=#080) or (ch=#13) or ((position=2) and (betFaced<plStack) and ((ch in ['0'..'9']) or (ch=#8)));

       IF (ch=#080) THEN
          IF position<numOfOptions THEN position:= position+1
          ELSE position:= 1
       ELSE IF (ch=#072) THEN
          IF position>1 THEN position:= position-1
          ELSE position:= numOfOptions
       ELSE IF position=2 then begin
          IF (length(toBet)<10) and (ch in ['0'..'9']) THEN
             IF not rewriting THEN toBet:= toBet+ch
             ELSE toBet:= ch
          ELSE IF ch=#8 THEN delete(toBet, length(toBet), 1);
       end;

       IF (ch=#13) and ((pos('BET', button[position].text)>0) or (pos('RAISE', button[position].text)>0)) THEN val(toBet, toBetValue);
     until (ch=#13) and not (((pos('BET', button[position].text)>0) or (pos('RAISE', button[position].text)>0)) and (toBetValue<minBet)); {ak stavuje, nech nestavuje jak idiot.. (zabezpecenie spravnej stavky)}

     IF button[position].text='FOLD' THEN folded:= true
     ELSE IF (button[position].text='CHECK') or (pos('CALL', button[position].text)>0) THEN betOwn:= 0
     ELSE IF pos('RAISE', button[position].text)>0 THEN
          IF (toBetValue-sidePotPl<=plStack) and (toBetValue-sidePotBot<=botStack) THEN betOwn:= toBetValue-sidePotBot
          ELSE IF plStack<botStack THEN betOwn:= plStack-betFaced
          ELSE betOwn:= botStack
     ELSE IF pos('BET', button[position].text)>0 THEN
          IF (toBetValue<plStack) and (toBetValue<botStack) THEN betOwn:= toBetValue
          ELSE IF plStack<botStack THEN betOwn:= plStack
          ELSE betOwn:= botStack;
     setfillstyle(1, 1);
     bar(xOptions, yOptions, xOptions+optionWidth, yOptions+round(optionHeight*4.5));
  end
  ELSE begin
    {bude sa to vetvit.. rozhodnutie bude zavisiet od toho, kde je hra (preflop/flop/turn/river), od toho ci hrac stavil alebo checkol atd.}
    {dost narychlo spraveny algortimus jeho rozhodovania.. informacie, ktore ma, bot nevyuziva nejak uzasne ale tak robi ako-tak zmysluplne rozhodnutia a nechce sa mi to vylepsovat}
    agression:= botStack/stack;  {ako velmi si bot moze dovolit byt agresivny}
    odds:= betFaced/(pot+sidePotPl+sidePotBot-betFaced); {ci sa mu matematicky oplati dorovnat}

    IF botFullHand[3].value=0 THEN begin {preflop}
       handWorth:= preflopAnalysis(botHand);

       IF odds=0 THEN begin{odds=0 > nestavil}
           IF handWorth>0.8 THEN betOwn:= random(blind)+blind
           ELSE betOwn:= 0
       end
       ELSE IF betFaced=blind div 2 THEN begin {small blind}
           IF agression<0.1 THEN betOwn:= botStack-betFaced
           ELSE IF agression<0.3 THEN begin
                IF handWorth>0.5 THEN betOwn:= botStack-betFaced
                ELSE folded:= true
           end
           ELSE IF agression<0.7 THEN begin
                IF handWorth>0.6 THEN betOwn:= random(blind)+blind
                ELSE IF handWorth>0.4 THEN betOwn:= 0
                ELSE folded:= true
           end
           ELSE IF agression<1.3 THEN begin
                IF handWorth>0.6 THEN betOwn:= random(2*blind)+blind
                ELSE IF handWorth<0.1 THEN folded:= true
                ELSE betOwn:= 0
           end
           ELSE begin
                IF handWorth>0.2 THEN betOwn:= botStack
                ELSE folded:= true
           end
       end
       ELSE begin {boli sme raisnuti.. uz to netreba moc hrotit, ak nemame premiovu handu}
           IF odds<handWorth THEN begin
              IF handWorth>0.8 THEN begin
                 IF random(2)=0 THEN betOwn:= random(betFaced)+betFaced
                 ELSE betOwn:= 0;
              end
              ELSE betOwn:= 0
           end
           ELSE IF handWorth>0.2 THEN betOwn:= 0
           ELSE folded:= true
       end
    end

    ELSE IF botFullHand[6].value=0 THEN begin {flop}
       botFullHand:= handSort(botFullHand, handInfo);
       handWorth:= handAnalysis(botFullHand, handInfo, board, botHand, 3);

       IF odds=0 THEN begin                 {begin - end su tu nepotrebne ale je to prehladnejsie}
           IF agression>1 THEN begin
              IF handWorth>0.5 THEN betOwn:= round(random(pot)+blind)
              ELSE betOwn:= 0
           end
           ELSE IF agression>0.5 THEN begin
              IF handWorth>0.7 THEN betOwn:= round(0.8*random(pot)+blind)
              ELSE betOwn:= 0
           end
       end
       ELSE IF odds<handWorth THEN begin
           IF handWorth>0.9 THEN begin
                 IF random(2)=0 THEN betOwn:= random(betFaced)+betFaced
                 ELSE betOwn:= 0;
           end
           ELSE betOwn:= 0
       end
       ELSE IF (odds>0.8) and (handWorth>0.8) THEN betOwn:= 0 {nechceme aby bot zahodil nuts len kvoli velkej stavke hraca}
       ELSE folded:= true
    end

    ELSE IF botFullHand[7].value=0 THEN begin {turn}
       botFullHand:= handSort(botFullHand, handInfo);
       handWorth:= handAnalysis(botFullHand, handInfo, board, botHand, 4);

       IF odds=0 THEN begin
           IF agression>1 THEN begin
              IF handWorth>0.5 THEN betOwn:= round(random(pot)+blind)
              ELSE betOwn:= 0
           end
           ELSE begin
              IF handWorth>0.7 THEN betOwn:= round(0.7*random(pot)+blind)
              ELSE betOwn:= 0
           end
       end
       ELSE IF odds<handWorth THEN begin
           IF handWorth>0.9 THEN
              IF random(2)=0 THEN betOwn:= random(betFaced)+betFaced
              ELSE betOwn:= 0
           ELSE betOwn:= 0
       end
       ELSE IF (odds>0.8) and (handWorth>0.8) THEN betOwn:= 0
       ELSE folded:= true
    end

    ELSE begin
       botFullHand:= handSort(botFullHand, handInfo);
       handWorth:= handAnalysis(botFullHand, handInfo, board, botHand, 5);

       IF odds=0 THEN begin
           IF agression>1 THEN begin
              IF handWorth>0.6 THEN betOwn:= round(random(pot)+blind)
              ELSE betOwn:= 0
           end
           ELSE begin
              IF handWorth>0.7 THEN betOwn:= round(0.6*random(pot)+blind)
              ELSE betOwn:= 0
           end
       end
       ELSE IF odds<handWorth THEN begin
           IF handWorth>0.9 THEN begin
                 IF random(2)=0 THEN betOwn:= random(betFaced)+betFaced
                 ELSE betOwn:= 0
           end
           ELSE betOwn:= 0
       end
       ELSE IF (odds>0.8) and (handWorth>0.8) THEN betOwn:= 0
       ELSE folded:= true
    end;
    IF (betOwn>plStack) or (betOwn>botStack) THEN
       IF (betOwn>plStack) THEN betOwn:= plStack
       ELSE betOwn:= botStack-betFaced;


    IF betOwn>0 THEN str(betOwn, displayBet);
    IF folded THEN botDecisionDisplay('FOLD')
    ELSE IF (betFaced=0) and (betOwn=0) THEN botDecisionDisplay('CHECK')
    ELSE IF (betFaced>0) and (betOwn=0) THEN botDecisionDisplay('CALL')
    ELSE IF (betFaced=0) and (betOwn>0) THEN botDecisionDisplay('BET '+displayBet)
    ELSE IF (betFaced>0) and (betOwn>0) THEN botDecisionDisplay('RAISE '+displayBet);
  end;
end;

procedure defineColors;
begin
  setRGBPalette(1, 7, 99, 36); {poker table zelena}
  setRGBPalette(2, 86, 0, 0); {krvavo cervena}
  setRGBPalette(3, 150, 150, 150); {robotsky seda}
  setRGBPalette(4, 0, 0, 0); {rasisticky cierna}
  setRGBPalette(5, 255, 255, 255); {biela bez zhodnych privlastkov}
  setRGBPalette(6, 213, 37, 20); {svetla cervena}
  setRGBPalette(7, 154,197,219); {diamantova}
  setRGBPalette(8, 255, 215, 0); {zlata}
  setRGBPalette(9, 125, 78, 56); {doutnikovo hneda}
  setRGBPalette(10, 200, 200, 200); {seda}
  setRGBPalette(11, 255,105,180); {ruzovucka}
  setRGBPalette(12, 100, 100, 100); {sedsia}
  setRGBPalette(13, 0, 153, 51); {ina zelena}
  setRGBPalette(14, 211, 192, 172); {klobuk svetlo hneda}
  setRGBPalette(15, 91, 37, 20); {klobuk tmavo hneda}
end;

procedure playPoker(stack: longint; blind: integer);

var plHand, botHand, plFullHand, botFullHand, board, winningHand: Thand;
    folded1, folded2, plButton, cardsTurned: boolean;
    plStack, botStack, bet1, bet2, pot, sidePotPl, sidePotBot: longint;
    winner: string;
    plHandInfo, botHandInfo: THandInfo;

begin
  randomize;
  cleardevice;

  setfillstyle(1, 1);
  fillellipse(maxX div 2, maxY div 2, round(maxX*0.4), round(maxY*0.4));
  drawPlayer;
  drawBot;

  IF random(2)=0 THEN plButton:= true
  ELSE plButton:= false;
  plStack:= stack;
  botStack:= stack;

  WHILE (plStack>0) and (botStack>0) do begin         {zaciatok handy}
    settextstyle(1, 0, 2);
    settextjustify(centertext, centertext);
    setcolor(4);
    IF plButton THEN begin
       setfillstyle(1, 5);
       setcolor(4);
       fillellipse(round(maxX*0.18), round(maxY*0.49), 15, 15);
       outtextxy(round(maxX*0.18), round(maxY*0.49), 'D');
       setfillstyle(1, 1);
       setcolor(1);
       fillellipse(round(maxX*0.8), round(maxY*0.5), 17, 17);
    end
    ELSE begin
       setfillstyle(1, 5);
       setcolor(4);
       fillellipse(round(maxX*0.8), round(maxY*0.5), 15, 15);
       outtextxy(round(maxX*0.8), round(maxY*0.5), 'D');
       setfillstyle(1, 1);
       setcolor(1);
       fillellipse(round(maxX*0.18), round(maxY*0.49), 17, 17);
    end;

    cardsTurned:= false;
    folded1:= false;
    folded2:= false;
    FOR i:= 1 to 7 do begin
       plHand[i].value:= 0; plHand[i].suit:= 0;
       plFullHand[i].value:= 0; plFullHand[i].suit:= 0;
       botHand[i].value:= 0; botHand[i].suit:= 0;
       botFullHand[i].value:= 0; botFullHand[i].suit:= 0; {board a winning hand nemusim nullifiovat}
    end;

    deck:= shuffledDeck(newDeck);
    plHand[1]:= deck[1]; plHand[2]:= deck[3];
    botHand[1]:= deck[2]; botHand[2]:= deck[4];
    board[1]:= deck[5]; board[2]:= deck[6]; board[3]:= deck[7]; board[4]:= deck[9]; board[5]:= deck[11];
    plFullHand[1]:= plHand[1]; plFullHand[2]:= plHand[2]; botFullHand[1]:= botHand[1]; botFullHand[2]:= botHand[2];

    drawCard(round(maxX*0.2), round(maxY*0.5), plHand[1], true);
    drawCard(round(maxX*0.72), round(maxY*0.4), botHand[1], false);
    drawCard(round(maxX*0.2+cardWidth*1.2), round(maxY*0.5), plHand[2], true);
    drawCard(round(maxX*0.72+cardWidth*1.2), round(maxY*0.4), botHand[2], false);
    FOR i:= 1 to 3 do drawCard(round(maxX*0.35+(i-1)*cardWidth*1.2), round(maxY*0.3), board[i], false);
    drawCard(round(maxX*0.35+cardWidth*4), round(maxY*0.3), board[4], false);
    drawCard(round(maxX*0.35+cardWidth*5.2), round(maxY*0.3), board[5], false);

    {poradie akcii zavisi od toho, kto ma "button", preto som sa rozhodol spravit funkcie bet a decision univerzalnymi, v ktorych menim jeden boolean parameter (na ukor prehladnosti tych funkcii)... takisto indexujem vars folded1 a folded2, nie plFolded/ botFolded, lebo sa to dynamicky meni}
    pot:= 0;
    sidePotPl:= 0;
    sidePotBot:= 0;
    drawStack(round(maxx*0.38), round(maxy*0.25), pot, 0, round(maxY*0.02), true);
    updateStackValue(round(maxx*0.42), round(maxy*0.16), pot, 'Pot: ');
    drawStack(round(maxX*0.3), round(maxy*0.53), sidePotPl, 0, round(maxY*0.02), true);
    updateStackValue(round(maxX*0.32), round(maxy*0.62), sidePotPl);
    drawStack(round(maxx*0.7), round(maxy*0.48), sidePotBot, 0, round(maxY*0.02), false);
    updateStackValue(round(maxX*0.65), round(maxy*0.57), sidePotBot);

    bet(plButton, blind div 2, plStack, botStack, sidePotPl, sidePotBot);
    bet(not plButton, blind, plStack, botStack, sidePotPl, sidePotBot);
    decision(plButton, board, plHand, plFullHand, botHand, botFullHand, blind div 2, plStack, botStack, sidePotPl, sidePotBot, pot, blind, bet1, folded1);

    IF not folded1 THEN begin
       bet(plButton, blind div 2+bet1, plStack, botStack, sidePotPl, sidePotBot);   {ocakavana preflop akcia na oboch stranach}
       decision(not plButton, board, plHand, plFullHand, botHand, botFullHand, bet1, plStack, botStack, sidePotPl, sidePotBot, pot, blind, bet2, folded2);
       IF not folded2 THEN bet(not plButton, bet1+bet2, plStack, botStack, sidePotPl, sidePotBot);
    end;

    WHILE not folded1 and not folded2 and (bet2>0) do begin {agresivne raisovanie}
       decision(plButton, board, plHand, plFullHand, botHand, botFullHand, bet2, plStack, botStack, sidePotPl, sidePotBot, pot, blind, bet1, folded1);
       IF not folded1 THEN begin
          bet(plButton, bet2+bet1, plStack, botStack, sidePotPl, sidePotBot);
          IF bet1>0 THEN begin
             decision(not plButton, board, plHand, plFullHand, botHand, botFullHand, bet1, plStack, botStack, sidePotPl, sidePotBot, pot, blind, bet2, folded2);
             IF not folded2 THEN bet(not plButton, bet1+bet2, plStack, botStack, sidePotPl, sidePotBot);
          end
          ELSE bet2:= 0; {len aby sa ukoncil cyklus.. bet2 uz nema vplyv}
       end;
    end;

    IF not folded1 and not folded2 THEN begin
      IF sidePotPl+sidePotBot>0 THEN delay(800);
      pot:= pot+sidePotPl+sidePotBot;
      sidePotPl:= 0;
      sidePotBot:= 0;
      drawStack(round(maxx*0.38), round(maxy*0.25), pot, 0, round(maxY*0.02), true);
      updateStackValue(round(maxx*0.42), round(maxy*0.16), pot, 'Pot: ');
      drawStack(round(maxX*0.3), round(maxy*0.53), sidePotPl, 0, round(maxY*0.02), true);
      updateStackValue(round(maxX*0.32), round(maxy*0.62), sidePotPl);
      drawStack(round(maxx*0.7), round(maxy*0.48), sidePotBot, 0, round(maxY*0.02), false);
      updateStackValue(round(maxX*0.65), round(maxy*0.57), sidePotBot);

      IF (plStack<=0) or (botStack<=0) THEN begin {stacilo by =, ale keby cistou neviem akou nahodou bol stack zaporny tak nech sa to sprava all-inovo.. uskodit to proste neuskodi..}
         drawCard(round(maxX*0.72), round(maxY*0.4), botHand[1], true);
         drawCard(round(maxX*0.72+cardWidth*1.2), round(maxY*0.4), botHand[2], true);    {otoc superove karty, odsimuluj situaciu}
         delay(1000);
         cardsTurned:= true;
      end;
      FOR i:= 1 to 3 do begin  {...a sme na flope}
         drawCard(round(maxX*0.35+(i-1)*cardWidth*1.2), round(maxY*0.3), board[i], true);
         plFullHand[i+2]:= board[i];
         botFullHand[i+2]:= board[i];
      end;
      IF (plStack<=0) or (botStack<=0) THEN delay(1000); {autootacanie, inak povedane decision-less otacanie, inak povedane all in simulacia, inak povedane all in mod, inak uz nepovedane}
      bet1:= 0; bet2:= 0;
    end;


    IF not folded1 and not folded2 and (plStack>0) and (botStack>0) THEN begin          {minimalna povinna akcia.. check-check/ bet-call}
       decision(not plButton, board, plHand, plFullHand, botHand, botFullHand, 0, plStack, botStack, sidePotPl, sidePotBot, pot, blind, bet2, folded2);
       IF not folded2 THEN begin
          bet(not plButton, bet2, plStack, botStack, sidePotPl, sidePotBot);
          decision(plButton, board, plHand, plFullHand, botHand, botFullHand, bet2, plStack, botStack, sidePotPl, sidePotBot, pot, blind, bet1, folded1);
          IF not folded1 THEN bet(plButton, bet2+bet1, plStack, botStack, sidePotPl, sidePotBot);
       end;
    end;

    WHILE not folded1 and not folded2 and (bet1>0) do begin
       decision(not plButton, board, plHand, plFullHand, botHand, botFullHand, bet1, plStack, botStack, sidePotPl, sidePotBot, pot, blind, bet2, folded2);
       IF not folded2 THEN begin
          bet(not plButton, bet1+bet2, plStack, botStack, sidePotPl, sidePotBot);
          IF bet2>0 THEN begin
             decision(plButton, board, plHand, plFullHand, botHand, botFullHand, bet2, plStack, botStack, sidePotPl, sidePotBot, pot, blind, bet1, folded1);
             IF not folded1 THEN bet(plButton, bet2+bet1, plStack, botStack, sidePotPl, sidePotBot);
          end
          ELSE bet1:= 0;
       end;
    end;

    IF not folded1 and not folded2 THEN begin
      IF sidePotPl+sidePotBot>0 THEN delay(800);
      pot:= pot+sidePotPl+sidePotBot;
      sidePotPl:= 0;
      sidePotBot:= 0;
      drawStack(round(maxx*0.38), round(maxy*0.25), pot, 0, round(maxY*0.02), true);
      updateStackValue(round(maxx*0.42), round(maxy*0.16), pot, 'Pot: ');
      drawStack(round(maxX*0.3), round(maxy*0.53), sidePotPl, 0, round(maxY*0.02), true);
      updateStackValue(round(maxX*0.32), round(maxy*0.62), sidePotPl);
      drawStack(round(maxx*0.7), round(maxy*0.48), sidePotBot, 0, round(maxY*0.02), false);
      updateStackValue(round(maxX*0.65), round(maxy*0.57), sidePotBot);

      IF not cardsTurned and (plStack<=0) or (botStack<=0) THEN begin
         drawCard(round(maxX*0.72), round(maxY*0.4), botHand[1], true);
         drawCard(round(maxX*0.72+cardWidth*1.2), round(maxY*0.4), botHand[2], true);
         delay(1000);
         cardsTurned:= true;
      end;
      drawCard(round(maxX*0.35+cardWidth*4), round(maxY*0.3), board[4], true);  {turn}
      plFullHand[6]:= board[4];
      botFullHand[6]:= board[4];
      IF (plStack<=0) or (botStack<=0) THEN delay(1000);
      bet1:= 0; bet2:= 0;
    end;

    IF not folded1 and not folded2 and (plStack>0) and (botStack>0) THEN begin          {minimalna povinna akcia.. check-check/ bet-call}
       decision(not plButton, board, plHand, plFullHand, botHand, botFullHand, 0, plStack, botStack, sidePotPl, sidePotBot, pot, blind, bet2, folded2);
       IF not folded2 THEN begin
          bet(not plButton, bet2, plStack, botStack, sidePotPl, sidePotBot);
          decision(plButton, board, plHand, plFullHand, botHand, botFullHand, bet2, plStack, botStack, sidePotPl, sidePotBot, pot, blind, bet1, folded1);
          IF not folded1 THEN bet(plButton, bet2+bet1, plStack, botStack, sidePotPl, sidePotBot);
       end;
    end;

    WHILE not folded1 and not folded2 and (bet1>0) do begin
       decision(not plButton, board, plHand, plFullHand, botHand, botFullHand, bet1, plStack, botStack, sidePotPl, sidePotBot, pot, blind, bet2, folded2);
       IF not folded2 THEN begin
          bet(not plButton, bet1+bet2, plStack, botStack, sidePotPl, sidePotBot);
          IF bet2>0 THEN begin
             decision(plButton, board, plHand, plFullHand, botHand, botFullHand, bet2, plStack, botStack, sidePotPl, sidePotBot, pot, blind, bet1, folded1);
             IF not folded1 THEN bet(plButton, bet2+bet1, plStack, botStack, sidePotPl, sidePotBot);
          end
          ELSE bet1:= 0;
       end;
    end;

    IF not folded1 and not folded2 THEN begin
      IF sidePotPl+sidePotBot>0 THEN delay(800);
      pot:= pot+sidePotPl+sidePotBot;
      sidePotPl:= 0;
      sidePotBot:= 0;
      drawStack(round(maxx*0.38), round(maxy*0.25), pot, 0, round(maxY*0.02), true);
      updateStackValue(round(maxx*0.42), round(maxy*0.16), pot, 'Pot: ');
      drawStack(round(maxX*0.3), round(maxy*0.53), sidePotPl, 0, round(maxY*0.02), true);
      updateStackValue(round(maxX*0.32), round(maxy*0.62), sidePotPl);
      drawStack(round(maxx*0.7), round(maxy*0.48), sidePotBot, 0, round(maxY*0.02), false);
      updateStackValue(round(maxX*0.65), round(maxy*0.57), sidePotBot);

      IF not cardsTurned and ((plStack<=0) or (botStack<=0)) THEN begin
         drawCard(round(maxX*0.72), round(maxY*0.4), botHand[1], true);
         drawCard(round(maxX*0.72+cardWidth*1.2), round(maxY*0.4), botHand[2], true);
         delay(1000);
         cardsTurned:= true;
      end;

      drawCard(round(maxX*0.35+cardWidth*5.2), round(maxY*0.3), board[5], true);  {river}
      plFullHand[7]:= board[5];
      botFullHand[7]:= board[5];
      IF (plStack<=0) or (botStack<=0) THEN delay(1000);
      bet1:= 0; bet2:= 0;
    end;

    IF not folded1 and not folded2 and (plStack>0) and (botStack>0) THEN begin          {minimalna povinna akcia.. check-check/ bet-call}
       decision(not plButton, board, plHand, plFullHand, botHand, botFullHand, 0, plStack, botStack, sidePotPl, sidePotBot, pot, blind, bet2, folded2);
       IF not folded2 THEN begin
          bet(not plButton, bet2, plStack, botStack, sidePotPl, sidePotBot);
          decision(plButton, board, plHand, plFullHand, botHand, botFullHand, bet2, plStack, botStack, sidePotPl, sidePotBot, pot, blind, bet1, folded1);
          IF not folded1 THEN bet(plButton, bet2+bet1, plStack, botStack, sidePotPl, sidePotBot);
       end;
    end;

    WHILE not folded1 and not folded2 and (bet1>0) do begin
       decision(not plButton, board, plHand, plFullHand, botHand, botFullHand, bet1, plStack, botStack, sidePotPl, sidePotBot, pot, blind, bet2, folded2);
       IF not folded2 THEN begin
          bet(not plButton, bet1+bet2, plStack, botStack, sidePotPl, sidePotBot);
          IF bet2>0 THEN begin
             decision(plButton, board, plHand, plFullHand, botHand, botFullHand, bet2, plStack, botStack, sidePotPl, sidePotBot, pot, blind, bet1, folded1);
             IF not folded1 THEN bet(plButton, bet2+bet1, plStack, botStack, sidePotPl, sidePotBot);
          end
          ELSE bet1:= 0;
       end;
    end;

    IF sidePotPl+sidePotBot>0 THEN delay(800);
    pot:= pot+sidePotPl+sidePotBot;
    sidePotPl:= 0;
    sidePotBot:= 0;
    drawStack(round(maxx*0.38), round(maxy*0.25), pot, 0, round(maxY*0.02), true);
    updateStackValue(round(maxx*0.42), round(maxy*0.16), pot, 'Pot: ');
    drawStack(round(maxX*0.3), round(maxy*0.53), sidePotPl, 0, round(maxY*0.02), true);
    updateStackValue(round(maxX*0.32), round(maxy*0.62), sidePotPl);
    drawStack(round(maxx*0.7), round(maxy*0.48), sidePotBot, 0, round(maxY*0.02), false);
    updateStackValue(round(maxX*0.65), round(maxy*0.57), sidePotBot);

    IF folded1 and plButton or folded2 and not plButton THEN winner:= '2'
    ELSE IF folded1 and not plButton or folded2 and plButton THEN winner:= '1'
    ELSE begin
       plFullHand:= handSort(plFullHand, plHandInfo);
       botFullHand:= handSort(botFullHand, botHandInfo);
       winner:= handComparison(plFullHand, botFullHand, plHandInfo, botHandInfo);
       IF winner='1' THEN winningHand:= plFullHand
       ELSE winningHand:= botFullHand; {split tu nemusime riesit, ak je split, proste sa zvyrazni stol}
    end;


    IF not folded1 and not folded2 THEN begin {showdown, zvyraznenie vitaznej handy}
       drawCard(round(maxX*0.72), round(maxY*0.4), botHand[1], true);
       drawCard(round(maxX*0.72+cardWidth*1.2), round(maxY*0.4), botHand[2], true);
       setlinestyle(solidln, 0, thickwidth);
       setcolor(8);
       FOR i:= 1 to 2 do
           IF contains(winningHand, plHand[i].value, plHand[i].suit) THEN
              rectangle(round(maxx*0.2+(i-1)*cardWidth*1.2), round(maxY*0.5), round(maxx*0.2+(i-1)*cardWidth*1.2)+cardWidth, round(maxY*0.5)+cardHeight);
       FOR i:= 1 to 2 do
           IF contains(winningHand, botHand[i].value, botHand[i].suit) THEN
              rectangle(round(maxx*0.72+(i-1)*cardWidth*1.2), round(maxY*0.4), round(maxx*0.72+(i-1)*cardWidth*1.2)+cardWidth, round(maxY*0.4)+cardHeight);
       FOR i:= 1 to 3 do
           IF contains(winningHand, board[i].value, board[i].suit) THEN
              rectangle(round(maxX*0.35+(i-1)*cardWidth*1.2), round(maxY*0.3), round(maxX*0.35+(i-1)*cardWidth*1.2)+cardWidth, round(maxY*0.3)+cardHeight);
       FOR i:= 4 to 5 do
           IF contains(winningHand, board[i].value, board[i].suit) THEN
              rectangle(round(round(maxx*0.35)+cardWidth*(4+1.2*(i-4))), round(maxY*0.3), round(round(maxx*0.35)+cardWidth*(4+1.2*(i-4))+cardWidth), round(maxY*0.3)+cardHeight);
       delay(2000);
    end;

    IF winner='1' THEN plStack:= plStack+pot
    ELSE IF winner='2' THEN botStack:= botStack+pot
    ELSE begin
       plStack:= plStack+pot div 2;
       botStack:= botStack+pot div 2; {pot nemoze byt neparny}
    end;

    plButton:= not plButton; {a vymenime poziciu..}
  end;
end;


begin
  stack:= 1000;
  blind:= 50;

  gm:= 0;
  gd:= detect;
  initGraph(gm, gd, 'C:/lazarus');
  IF graphResult=grOK THEN begin
     maxX:= getmaxX; {nech nezistuje pri kazdom pouziti odznova rozlisenie.. neviem ci to je takto nejak moc efektivnejsie ale myslim ze menej nie}
     maxY:= getmaxY;
     xOptions:= round(maxX*0.45);
     yOptions:= round(maxY*0.65);
     optionWidth:= round(maxx*0.1);  {tlacitka CALL, BET, FOLD, CHECK}
     optionHeight:= round(maxy*0.05);
     cardWidth:= round(maxx*0.03);
     cardHeight:= round(maxy*0.08);
     defineColors;

     play:= true;
     WHILE play do begin
         menu(play);
         IF play THEN playPoker(stack, blind);
     end;
  end;
end.

