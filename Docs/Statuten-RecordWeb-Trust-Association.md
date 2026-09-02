# Statuten des Vereins RecordWeb Trust Association

**Stand:** Entwurf vom 2. September 2026 (überarbeitet)
**Rechtsgrundlage:** Art. 60 ff. des Schweizerischen Zivilgesetzbuches (ZGB)

---

## Vorbemerkung zur Namenswahl und Domain

Im Umfeld internationaler, W3C-naher Standardisierungsinitiativen werden Betreiber- bzw. Koordinationsorganisationen für dezentrale/verteilte Vertrauensinfrastrukturen typischerweise nicht als reine Kürzel, sondern mit einem Funktionszusatz benannt, der die koordinierende, treuhänderische Rolle ausdrückt (z. B. *Trust over IP Foundation*, *Sovrin Foundation*, *Decentralized Identity Foundation*). Diese Organisationen firmieren fast durchgehend als *Foundation* oder *Association*, nicht als reine Namensmarke ohne Zusatz.

**Name (bestätigt):** **„RecordWeb Trust Association“** (Kürzel: **RWTA**). Der Zusatz *Trust Association* transportiert die treuhänderische Koordinationsrolle (analog *Trust over IP Foundation*) und positioniert den Verein klar als **Übergangs-Betreiberorganisation** im Sinne von RWC #17, nicht als Eigentümerin des Netzwerks.

**Domain (bestätigt):** **`recordweb.org`** ist als institutionelle Domain des Vereins vorgesehen (frei verfügbar geprüft) und bewusst von `recordweb.dev` (technische Pilot-Domain, im Eigentum der Projektleitung/TRIEBWERKSTATT) getrennt — analog zur Praxis vergleichbarer Koordinationsorganisationen (z. B. *trustoverip.org*), die ihre institutionelle Identität von einer technischen Projekt-Domain trennen.

Diese Statuten sind als **Diskussionsentwurf** zu verstehen. Rot markierte Annahmen (Sitz Bern, Gründungsdatum 1. September 2026) sind gemäss Auftrag fiktiv gesetzt und vor der eigentlichen Gründungsversammlung zu bestätigen.

---

## I. Name, Sitz, Zweck

### Art. 1 – Name

Unter dem Namen **„RecordWeb Trust Association“** (nachfolgend „der Verein“) besteht ein Verein im Sinne von Art. 60 ff. des Schweizerischen Zivilgesetzbuches (ZGB), mit unbestimmter Dauer.

### Art. 2 – Sitz

Der Sitz des Vereins ist in **Bern**, Kanton Bern.

### Art. 3 – Zweck

1. Der Verein bezweckt die **Koordination, Governance und den Übergangsbetrieb des globalen RecordWeb RootResolver Network** gemäss den Anforderungen der RecordWeb Community Group (RWC) und des RecordWeb-Protokolls (RWP), insbesondere gemäss RWC-Issue #17 (Governance- und Betriebsanforderungen für das globale RootResolver-Netzwerk).

2. Der Verein handelt dabei als **koordinierende Instanz ohne Eigentum an den im Netzwerk verwalteten Daten oder Namespace-Einträgen**. Er ist nicht Eigentümerin sämtlicher Namespaces und nicht Betreiberin sämtlicher DID-Resolver; seine Rolle beschränkt sich auf die Koordination der gemeinsam genutzten Namespace-Resolution-Infrastruktur und der Verfahren, die deren Integrität, Verfügbarkeit und Interoperabilität sicherstellen.

3. Der Verein versteht sich ausdrücklich als **Übergangsorganisation** (siehe Art. 5). Er ist darauf ausgelegt, dass seine Mitgliederstruktur im Zeitverlauf vollständig von nicht-staatlichen Pilot-Organisationen zu staatlichen bzw. staatlich delegierten Organisationen übergeht, wie in Art. 5 und Art. 8–12 näher geregelt.

4. Der Verein kann zur Erfüllung seines Zwecks selbst eine minimale technische Anlaufstelle im Netzwerk betreiben (Art. 5 Abs. 4).

5. Der Verein verfolgt keine wirtschaftlichen Zwecke und erstrebt keinen Gewinn. Er ist politisch unabhängig und konfessionell neutral.

### Art. 4 – Mittel

Zur Verfolgung des Vereinszwecks verfügt der Verein über folgende Mittel:

- Beiträge der Mitglieder (Aufnahme- und/oder Jahresbeiträge, sofern von der Vereinsversammlung beschlossen);
- Zuwendungen, Spenden und Subventionen jeglicher Art, insbesondere von öffentlich-rechtlichen Trägern;
- Erträge aus eigenen Veranstaltungen oder Leistungsvereinbarungen;
- Sachleistungen der Mitglieder, insbesondere die von den Mitgliedern selbst betriebene technische Infrastruktur (siehe Art. 8), die dem Verein im Rahmen der Mitgliedschaft unentgeltlich zur Erfüllung des Vereinszwecks zur Verfügung gestellt wird.

Für die Verbindlichkeiten des Vereins haftet ausschliesslich das Vereinsvermögen; eine persönliche Haftung der Mitglieder ist ausgeschlossen (Art. 75a ZGB).

---

## II. Mitgliedschaft

### Art. 5 – Grundprinzip: Kopplung von Netzwerkbetrieb und Mitgliedschaft

1. Mitglied des Vereins kann **ausschliesslich** werden, wer im Sinne der technischen Netzwerkspezifikation eine **Organisation im RecordWeb RootResolver Network** betreibt (nachfolgend „Netzwerk-Organisation“). Es gibt keine Vereinsmitgliedschaft ohne Betrieb einer Netzwerk-Organisation und keinen Betrieb einer Netzwerk-Organisation ohne gleichzeitige Vereinsmitgliedschaft, vorbehalten bleibt Abs. 4.

2. Wer den Betrieb ihrer/seiner Netzwerk-Organisation gemäss dem im Netzwerk geltenden Standard-Austrittsverfahren beendet, scheidet **gleichzeitig und automatisch** aus dem Verein aus, ohne dass es einer gesonderten Rücktrittserklärung bedarf (vorbehalten bleibt Art. 10 Abs. 3 betreffend Fristen).

3. Diese Kopplung dient dem in Art. 3 Abs. 3 festgehaltenen Übergangszweck: Der Verein wandelt sich durch diese Regel automatisch von einer anfänglich durch nicht-staatliche Pilot-Organisationen getragenen Struktur zu einer ausschliesslich durch staatliche bzw. staatlich delegierte Organisationen getragenen Struktur, ohne dass eine gesonderte Restrukturierung notwendig wird.

4. **Ausnahme – vereinseigene Anlaufstelle**: Der Verein kann selbst eine minimale, nicht endorsierende Netzwerk-Organisation betreiben (bestehend insbesondere aus einer Fabric Certificate Authority und einem einzelnen, welt-bekannten Peer unter der Adresse `peer.recordweb.org`), die ausschliesslich als stabiler Erstkontakt- und Discovery-Punkt für andere Organisationen im Netzwerk dient und **keine aktive Rolle in der Transaktionsverarbeitung** übernimmt (insbesondere kein Endorsement, kein Betrieb eines Orderers). Diese vereinseigene Organisation begründet **keine zusätzliche, von der Vereinsmitgliedschaft losgelöste Mitgliedschaft** und unterliegt nicht der Kopplungsregel gemäss Abs. 1–2; sie ist eine operative Funktion des Vereins selbst.

### Art. 6 – Gründungsmitglieder

Gründungsmitglieder des Vereins per Gründungsdatum (Art. 21) sind die Betreiber folgender Pilot-Netzwerk-Organisationen:

- **TRIEBWERKSTATT** (Kürzel: TWS);
- die von **Melvin Carvalho** betriebene Organisation (Kürzel: MC);
- die von **Nicolas Bürkler** betriebene Organisation (Kürzel: NB).

Diese Gründungsmitgliedschaften sind ausdrücklich **nicht-staatlicher Natur** und unterliegen den Übergangsregeln gemäss Art. 5 und Art. 9.

### Art. 7 – Mitgliederkategorien

1. Der Verein unterscheidet zwei Kategorien von Mitgliedern:

   a. **Pilot-Mitglieder**: Mitglieder, deren Netzwerk-Organisation nicht durch eine Regierung oder eine von einer Regierung delegierte Organisation betrieben wird (insb. die Gründungsmitglieder gemäss Art. 6).

   b. **Staatliche Mitglieder**: Mitglieder, deren Netzwerk-Organisation entweder durch eine Landesregierung selbst oder durch eine von dieser formell delegierte Organisation betrieben wird (Beispiele: eine nationale Behörde direkt, oder eine Trägerorganisation wie die Digitale Verwaltung Schweiz DVS oder der Verein eCH, sofern die betreffende Regierung diese Organisation formell mit der Vertretung in dieser Angelegenheit betraut hat).

2. Die Zuordnung zu einer Kategorie ist für die Anwendung von Art. 9 (Stimmrecht), Art. 10 (Austrittsfristen) und Art. 12 (Betriebsphase) massgebend.

3. Die vereinseigene Anlaufstelle gemäss Art. 5 Abs. 4 fällt nicht unter diese Kategorisierung, da sie keine Mitgliedschaft begründet.

### Art. 8 – Aufnahme

1. Über die Aufnahme neuer Mitglieder entscheidet die Vereinsversammlung auf Antrag des Vorstands.

2. Aufnahmevoraussetzungen sind:

   a. die technische Fähigkeit, eine Netzwerk-Organisation gemäss dem im Netzwerk geltenden einheitlichen Knotenmodell (1 Fabric-CA, 2 Orderer, 2 Peers, oder das jeweils gültige Referenzmodell) zuverlässig zu betreiben;

   b. die Anerkennung dieser Statuten sowie der technischen und Governance-Vorgaben des RecordWeb RootResolver Network;

   c. für die Aufnahme als **staatliches Mitglied** (Art. 7 Abs. 1 lit. b): der Nachweis, dass die antragstellende Organisation entweder selbst eine Landesregierung ist, oder von einer Landesregierung formell zur Vertretung in dieser Angelegenheit delegiert wurde.

3. Aufnahmebeschlüsse erfolgen mit dem in Art. 9 festgelegten Mehrheits- bzw. Vetorecht-Erfordernis.

4. Mit der Aufnahme in den Verein ist zugleich das im Netzwerk geltende technische Onboarding-Verfahren (Aufbau der Membership Service Provider, Erstellung der Knoten-Identitäten, Anpassung der Kanal- und Endorsement-Konfiguration) einzuleiten.

### Art. 9 – Stimmrecht und Beschlussfassung

1. **Während der Testphase** (solange mindestens ein Pilot-Mitglied im Verein ist): Beschlüsse der Vereinsversammlung erfolgen mit einfacher Mehrheit der anwesenden bzw. vertretenen Mitglieder; dem Gründungsmitglied **TRIEBWERKSTATT** steht dabei ein **Vetorecht** zu, mit dem es einen mehrheitlich gefassten Beschluss verhindern kann.

2. **Während der Betriebsphase** (sobald die Testphase gemäss Art. 12 beendet ist): Beschlüsse erfolgen mit einfacher Mehrheit der anwesenden bzw. vertretenen Mitglieder; ein Vetorecht besteht für kein Mitglied mehr.

3. Jedes Mitglied verfügt über eine Stimme, unabhängig von der Kategorie gemäss Art. 7.

4. Statutenänderungen bedürfen, unbeschadet Abs. 1–2, zusätzlich der in Art. 20 genannten qualifizierten Mehrheit.

### Art. 10 – Austritt

1. Ein Mitglied kann jederzeit unter Einhaltung der nachfolgenden Fristen aus dem Verein austreten, indem es den Betrieb seiner Netzwerk-Organisation gemäss dem im Netzwerk geltenden Standard-Austrittsverfahren beendet (Art. 5 Abs. 2).

2. Die Mindestkündigungsfrist beträgt:

   a. **1 Monat** für Pilot-Mitglieder (Art. 7 Abs. 1 lit. a);

   b. **1 Jahr** für staatliche Mitglieder (Art. 7 Abs. 1 lit. b).

3. Diese differenzierten Fristen orientieren sich an vergleichbaren internationalen Konsortialstrukturen (namentlich EUROPEUM-EDIC, dem europäischen Konsortium für gemeinsame verteilte Ledger-Infrastruktur zwischen Mitgliedstaaten, das für staatliche Mitglieder eine Kündigungsfrist von zwölf Monaten vorsieht) und tragen dem Umstand Rechnung, dass ein Austritt eines staatlichen Mitglieds eine geordnete Übergabe hoheitlicher Verantwortlichkeiten erfordert, während ein Austritt eines Pilot-Mitglieds primär technisch-organisatorischer Natur ist.

4. Mit Wirksamwerden des Austritts erlischt die Mitgliedschaft im Verein automatisch und gleichzeitig mit der Beendigung des Betriebs der Netzwerk-Organisation (Art. 5 Abs. 2).

5. War das austretende Mitglied Trägerin einer Ersatzverantwortlichkeit gemäss Art. 13 Abs. 2, ist diese Verantwortlichkeit vor Wirksamwerden des Austritts ausdrücklich neu zuzuweisen.

### Art. 11 – Ausschluss

1. Ein Mitglied kann durch Beschluss der Vereinsversammlung mit der in Art. 9 festgelegten Mehrheit aus dem Verein ausgeschlossen werden, wenn es seinen Pflichten aus diesen Statuten oder aus der technischen und Governance-Ordnung des Netzwerks in schwerer Weise wiederholt nicht nachkommt, insbesondere bei anhaltender Nichterfüllung des Betriebs seiner Netzwerk-Organisation, bei Verstössen gegen die Endorsement- oder Sicherheitsvorgaben des Netzwerks, oder bei Handlungen, die die Integrität des Namespace-Registers gefährden.

2. Vor einem Ausschlussbeschluss ist dem betroffenen Mitglied rechtliches Gehör zu gewähren.

3. Der Ausschluss ist zugleich als Beendigung des Betriebs der Netzwerk-Organisation zu vollziehen, unter sinngemässer Anwendung des technischen Austrittsverfahrens (Entzug von MSP, Orderer- und Peer-Berechtigungen, Anpassung der Endorsement-Policy).

### Art. 12 – Ende der Testphase und Übergang in die Betriebsphase

1. Die Testphase des Netzwerks und des Vereins gilt als beendet, wenn beide der folgenden Bedingungen gleichzeitig erfüllt sind:

   a. kein Pilot-Mitglied (Art. 7 Abs. 1 lit. a) ist mehr im Verein vertreten, das heisst, sämtliche Gründungsmitglieder gemäss Art. 6 sowie allfällige weitere Pilot-Mitglieder sind gemäss Art. 10 ausgetreten oder gemäss Art. 11 ausgeschlossen worden; und

   b. der Verein besteht ausschliesslich aus staatlichen Mitgliedern gemäss Art. 7 Abs. 1 lit. b.

2. Mit Eintritt dieser Bedingungen endet automatisch das Vetorecht gemäss Art. 9 Abs. 1, und es gilt ab diesem Zeitpunkt ausschliesslich die einfache Mehrheit gemäss Art. 9 Abs. 2.

3. Der Übergang in die Betriebsphase ist zugleich Voraussetzung für die Freigabe des produktiven Betriebskanals („prod“) des Netzwerks gemäss der technischen Netzwerkkonfiguration; vor Eintritt dieser Bedingungen erfolgen sämtliche Registrierungen ausschliesslich auf dem Testkanal („test“).

4. Die vereinseigene Anlaufstelle gemäss Art. 5 Abs. 4 bleibt vom Übergang in die Betriebsphase unberührt und wird unabhängig von der Mitgliederentwicklung weiterbetrieben.

---

## III. Organisation

### Art. 13 – Organe

Die Organe des Vereins sind:

1. die Vereinsversammlung;
2. der Vorstand;
3. die Revisionsstelle (sofern nach Art. 18 bestellt).

### Art. 13a – Verantwortlichkeit während der Pilotphase

1. Solange der Verein Pilot-Mitglieder umfasst, übernimmt das Gründungsmitglied **TRIEBWERKSTATT** die **subsidiäre operative Verantwortung** für die Infrastruktur, die Domainverwaltung (`recordweb.org` sowie die technische Anlaufstelle gemäss Art. 5 Abs. 4) und die datenschutzrechtlichen Aspekte des Pilotbetriebs, sofern die Vereinsversammlung keine abweichende Regelung beschliesst.

2. Diese Ersatzverantwortlichkeit ist bei Austritt von TRIEBWERKSTATT gemäss Art. 10 Abs. 5 ausdrücklich neu zuzuweisen.

### Art. 14 – Vereinsversammlung: Zuständigkeit

Der Vereinsversammlung stehen insbesondere folgende unübertragbare Befugnisse zu:

1. Wahl und Abwahl des Vorstands sowie gegebenenfalls der Revisionsstelle;
2. Genehmigung des Jahresberichts, der Jahresrechnung und des Budgets;
3. Beschlussfassung über Aufnahme, Ausschluss und Kategorisierung von Mitgliedern (Art. 7, 8, 11);
4. Beschlussfassung über die Governance-Ordnung des RecordWeb RootResolver Network, einschliesslich Namespace-Registrierungsregeln, Endorsement-Policy und technischer Netzwerkkonfiguration, im Rahmen der Vorgaben von RWC und RWP;
5. Beschlussfassung über Errichtung, Standort und Betrieb der vereinseigenen Anlaufstelle gemäss Art. 5 Abs. 4;
6. Statutenänderungen (Art. 20);
7. Beschluss über die Auflösung des Vereins (Art. 22).

### Art. 15 – Vereinsversammlung: Einberufung

1. Die ordentliche Vereinsversammlung findet einmal jährlich statt.

2. Ausserordentliche Versammlungen sind einzuberufen, wenn der Vorstand dies beschliesst oder wenn mindestens ein Fünftel der Mitglieder dies schriftlich unter Angabe der Gründe verlangt.

3. Die Einberufung erfolgt schriftlich (auch elektronisch) mit einer Frist von mindestens 20 Tagen unter Angabe der Traktanden.

### Art. 16 – Vorstand

1. Der Vorstand besteht aus mindestens drei Mitgliedern und wird von der Vereinsversammlung für eine Amtsdauer von zwei Jahren gewählt; Wiederwahl ist möglich.

2. Der Vorstand führt die laufenden Geschäfte des Vereins, vertritt ihn nach aussen und ist für die operative Koordination des RecordWeb RootResolver Network im Rahmen der von der Vereinsversammlung beschlossenen Governance-Ordnung zuständig.

3. Der Vorstand konstituiert sich selbst und bezeichnet insbesondere eine Präsidentin oder einen Präsidenten.

4. Der Vorstand kann Fachausschüsse (z. B. für technische Netzwerkfragen) einsetzen und mit spezifischen Aufgaben betrauen.

### Art. 17 – Zeichnungsberechtigung

Der Verein wird durch die Präsidentin oder den Präsidenten des Vorstands zusammen mit einem weiteren Vorstandsmitglied rechtsverbindlich verpflichtet (Kollektivunterschrift zu zweien).

### Art. 18 – Revisionsstelle

Sofern gesetzlich erforderlich oder von der Vereinsversammlung beschlossen, bestellt die Vereinsversammlung eine Revisionsstelle, die die Jahresrechnung prüft und der Vereinsversammlung Bericht erstattet.

---

## IV. Finanzen

### Art. 19 – Geschäftsjahr

Das Geschäftsjahr des Vereins entspricht dem Kalenderjahr. Das erste Geschäftsjahr dauert vom Gründungsdatum (Art. 21) bis zum folgenden 31. Dezember.

---

## V. Schlussbestimmungen

### Art. 20 – Statutenänderung

Eine Änderung dieser Statuten bedarf eines Beschlusses der Vereinsversammlung mit einer Mehrheit von zwei Dritteln der anwesenden bzw. vertretenen Mitglieder. Das Vetorecht gemäss Art. 9 Abs. 1 findet auf Statutenänderungen **keine** Anwendung; diese unterliegen ausschliesslich dem qualifizierten Mehrheitserfordernis dieses Artikels.

### Art. 21 – Gründung und Inkrafttreten

Diese Statuten wurden von der Gründungsversammlung am **1. September 2026** *(fiktives Datum gemäss Auftrag; vor der tatsächlichen Gründung zu bestätigen)* in **Bern** beschlossen und treten mit diesem Datum in Kraft.

### Art. 22 – Auflösung

1. Die Auflösung des Vereins bedarf eines Beschlusses der Vereinsversammlung mit einer Mehrheit von zwei Dritteln der anwesenden bzw. vertretenen Mitglieder.

2. Im Falle der Auflösung wird ein allfälliges Vereinsvermögen nicht unter den Mitgliedern verteilt, sondern einer Organisation mit ähnlicher, gemeinnütziger Zwecksetzung im Bereich offener Standards oder digitaler Infrastruktur zugeführt, die von der Vereinsversammlung im Auflösungsbeschluss zu bestimmen ist. Eine Rückverteilung an die Mitglieder ist ausgeschlossen.

3. Eine Auflösung im Sinne dieses Artikels ist von der in Art. 5 und Art. 12 vorgesehenen automatischen Verschlankung der Mitgliedschaft (Übergang von Pilot- zu staatlichen Mitgliedern) zu unterscheiden; letztere führt nicht zur Auflösung des Vereins, sondern zu dessen Fortführung in transformierter Form.

---

## Anhang: Offene Punkte vor der eigentlichen Gründung

- Bestätigung des Sitzes Bern (Art. 2) sowie der genauen politischen Gemeinde (z. B. Stadt Bern) für den Handelsregistereintrag.
- Bestätigung bzw. Neufestsetzung des Gründungsdatums (Art. 21); der 1. September 2026 wurde fiktiv gemäss Auftrag eingesetzt.
- Klärung, ob eine Revisionsstelle für den Pilotbetrieb bereits erforderlich ist (abhängig von Bilanzsumme/Ertrag; bei einem reinen Koordinationsverein ohne wesentliche Mittel in der Pilotphase in der Regel nicht zwingend).
- Konkrete Ausgestaltung der Mitgliederbeiträge (Art. 4), falls gewünscht — aktuell nicht vorgesehen, da die Mitglieder primär Sachleistungen (Infrastrukturbetrieb) erbringen.
- Prüfung der Steuerbefreiung (Art. 3 Zweckformulierung ist bewusst nicht-wirtschaftlich gehalten, um dies zu ermöglichen; eine formelle Prüfung durch die kantonale Steuerverwaltung Bern steht noch aus).
- Klärung, wo genau die vereinseigene Anlaufstelle (Art. 5 Abs. 4, `peer.recordweb.org`) technisch gehostet wird (z. B. anfänglich auf der TWS-Infrastruktur, oder auf separater, dem Verein direkt zurechenbarer Infrastruktur) — siehe auch RootResolver-Network-Dokument, offene Frage Nr. 3.
