#I made this script to discover the formula to calculate perfect flashloan to leverage, sorry I'm bad at maths :(

def simulateCalc(collateral, minCollatPerc):
    print("coll", collateral, "min", minCollatPerc)
    for x in range(60000):
        e = x * 1 #e == flashloan
        t = e + collateral #collateral + flashloan
        borrowable = (t * 100) / minCollatPerc #total to borrow from protocol
        diff = borrowable - e #diff between protocol debt and flashloan debt
        if(diff <= 5 and diff >= 0):
            print("f:",e,"tc:",t,"b:",borrowable,"d:",diff)

def calc(collateral, minCollatPerc):
    #flashloan == (collateral * 100) / minCollatPerc - 100
    print("c:", collateral, "m:", minCollatPerc, "f:", (collateral * 100) / (minCollatPerc - 100))

for x in range(60):
    calc(2000 + (x * 1000), 145)